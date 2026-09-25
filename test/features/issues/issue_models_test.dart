import 'package:agrilink_mobile/features/issues/data/advisory.dart';
import 'package:agrilink_mobile/features/issues/data/crop_issue.dart';
import 'package:agrilink_mobile/features/issues/data/issue_enums.dart';
import 'package:flutter_test/flutter_test.dart';

import 'issue_fixtures.dart';

void main() {
  group('enums', () {
    test('read the API strings and keep them in apiName', () {
      expect(IssueSeverity.fromApi('Medium'), IssueSeverity.medium);
      expect(RiskLevel.fromApi('High').apiName, 'High');
      expect(IssueStatus.fromApi('AwaitingReview'), IssueStatus.awaitingReview);
      expect(IssueStatus.awaitingReview.apiName, 'AwaitingReview');
      for (final status in AdvisoryStatus.values) {
        expect(AdvisoryStatus.fromApi(status.apiName), status);
      }
    });

    test('an unknown value is a clear error, not a wrong status', () {
      expect(() => IssueStatus.fromApi('Exploded'), throwsFormatException);
      expect(() => AdvisoryStatus.fromApi(null), throwsFormatException);
    });

    test('only a draft advisory is hidden from farmers', () {
      expect(AdvisoryStatus.draft.isReleased, isFalse);
      expect(AdvisoryStatus.preliminary.isReleased, isTrue);
      expect(AdvisoryStatus.approved.isReleased, isTrue);
      expect(AdvisoryStatus.rejected.isReleased, isTrue);
      expect(AdvisoryStatus.preliminary.isDecided, isFalse);
      expect(AdvisoryStatus.rejected.isDecided, isTrue);
    });
  });

  group('CropIssue', () {
    test('parses a full response, reading a time without an offset as UTC', () {
      final issue = CropIssue.fromJson(issueJson());
      expect(issue.id, 7);
      expect(issue.cropType, 'Green Gram');
      expect(issue.severity, IssueSeverity.high);
      expect(issue.status, IssueStatus.awaitingReview);
      expect(issue.createdAt, DateTime.utc(2026, 9, 20, 8, 30));
      expect(issue.hasPhoto, isTrue);
      expect(issue.advisoryId, 21);
      expect(issue.advisoryStatus, AdvisoryStatus.draft);
    });

    test('has no advisory yet', () {
      final issue = CropIssue.fromJson(issueJson(advisoryId: null, advisoryStatus: null));
      expect(issue.advisoryId, isNull);
      expect(issue.advisoryStatus, isNull);
      expect(issue.reviewedAt, isNull);
      expect(issue.reviewNote, isNull);
      expect(issue.hasReleasedAdvisory, isFalse);
    });

    test('a farmer can open the advisory in every status except draft', () {
      bool canOpen(String status) =>
          CropIssue.fromJson(issueJson(advisoryStatus: status)).hasReleasedAdvisory;
      expect(canOpen('Draft'), isFalse);
      expect(canOpen('Preliminary'), isTrue);
      expect(canOpen('Approved'), isTrue);
      expect(canOpen('Rejected'), isTrue);
    });

    test('a missing required field names what is wrong', () {
      final json = issueJson()..remove('title');
      expect(() => CropIssue.fromJson(json), throwsA(isA<FormatException>()));
    });
  });

  group('CreateCropIssueRequest', () {
    test('sends the severity as the API string', () {
      const request = CreateCropIssueRequest(
        cropId: 3,
        title: 'Yellow leaves',
        description: 'Turning yellow.',
        severity: IssueSeverity.low,
      );
      expect(request.toJson(), {
        'cropId': 3,
        'title': 'Yellow leaves',
        'description': 'Turning yellow.',
        'severity': 'Low',
      });
    });
  });

  group('Advisory', () {
    test('parses a farmer response: officer-only fields and officer fields are null', () {
      final advisory = Advisory.fromJson(farmerAdvisoryJson());
      expect(advisory.id, 21);
      expect(advisory.status, AdvisoryStatus.approved);
      expect(advisory.riskLevel, RiskLevel.medium);
      expect(advisory.confidencePercent, 87);
      expect(advisory.issueCreatedAt, DateTime.utc(2026, 9, 20, 8, 30));
      expect(advisory.reviewedById, isNull);
      expect(advisory.reviewedByName, isNull);
      expect(advisory.reviewedAt, isNull);
      expect(advisory.reviewNote, isNull);
      expect(advisory.previousIssues, isNull);
      expect(advisory.agentTrace, isNull);
      expect(advisory.photoDiagnosis, isNull);
      expect(advisory.officerTreatment, isNull);
      expect(advisory.photos, isEmpty);
    });

    test('reads each status', () {
      for (final status in AdvisoryStatus.values) {
        final advisory = Advisory.fromJson(farmerAdvisoryJson(status: status.apiName));
        expect(advisory.status, status);
      }
    });

    test('parses the officer’s review and the photos', () {
      final advisory = Advisory.fromJson(
        farmerAdvisoryJson(
          extra: {
            'reviewedByFK': 4,
            'reviewedByName': 'K. Silva',
            'reviewedAt': '2026-09-21T10:00:00Z',
            'reviewNote': 'Looks right.',
            'officerTreatment': 'Spray neem oil weekly.',
            'confirmedDiseaseKey': 'yellow_mosaic',
            'confirmedDiseaseName': 'Yellow Mosaic',
            'photoDiagnosis': {'diseaseKey': 'yellow_mosaic', 'diseaseName': 'Yellow Mosaic'},
            'photos': [
              {'imageId': 9, 'url': '/api/issues/7/images/9', 'width': 1200, 'height': 1600},
            ],
          },
        ),
      );
      expect(advisory.reviewedByName, 'K. Silva');
      expect(advisory.reviewedAt, DateTime.utc(2026, 9, 21, 10));
      expect(advisory.reviewNote, 'Looks right.');
      expect(advisory.officerTreatment, 'Spray neem oil weekly.');
      expect(advisory.confirmedDiseaseName, 'Yellow Mosaic');
      expect(advisory.photoDiagnosis!.diseaseName, 'Yellow Mosaic');
      // A farmer's diagnosis carries no model details.
      expect(advisory.photoDiagnosis!.modelConfidence, isNull);
      expect(advisory.photoDiagnosis!.diseaseOptions, isNull);
      expect(advisory.photos.single.url, '/api/issues/7/images/9');
      expect(advisory.photos.single.height, 1600);
    });

    test('parses everything an officer receives', () {
      final advisory = Advisory.fromJson(
        farmerAdvisoryJson(
          status: 'Preliminary',
          extra: {
            'requiresApproval': true,
            'previousIssues': [
              {
                'issueId': 5,
                'title': 'Aphids',
                'severity': 'Low',
                'status': 'Resolved',
                'createdAt': '2026-08-01T00:00:00Z',
                'advisoryId': 12,
              },
              {
                'issueId': 6,
                'title': 'Wilting',
                'severity': 'Medium',
                'status': 'Pending',
                'createdAt': '2026-08-15T00:00:00Z',
                'advisoryId': null,
              },
            ],
            'agentTrace': {
              'objective': 'Assess the issue',
              'status': 'Completed',
              'startedAt': '2026-09-20T08:30:01Z',
              'completedAt': '2026-09-20T08:30:20Z',
              'steps': [
                {
                  'agentName': 'PhotoAgent',
                  'status': 'Completed',
                  'startedAt': '2026-09-20T08:30:02Z',
                  'completedAt': null,
                  'input': {'crop': 'Green Gram'},
                  'output': 'plain text',
                },
              ],
            },
            'photoDiagnosis': {
              'diseaseKey': 'yellow_mosaic',
              'diseaseName': 'Yellow Mosaic',
              'modelConfidence': 0.93,
              'modelVersion': 'v3',
              'escalationReasons': ['LowMargin', 'HighSeverity'],
              'suggestedTreatment': 'Remove infected plants.',
              'diseaseOptions': [
                {'key': 'yellow_mosaic', 'name': 'Yellow Mosaic'},
                {'key': 'other', 'name': 'Other'},
              ],
            },
          },
        ),
      );
      expect(advisory.requiresApproval, isTrue);
      expect(advisory.previousIssues, hasLength(2));
      expect(advisory.previousIssues!.first.status, IssueStatus.resolved);
      expect(advisory.previousIssues!.last.advisoryId, isNull);
      final step = advisory.agentTrace!.steps.single;
      expect(step.agentName, 'PhotoAgent');
      expect(step.completedAt, isNull);
      expect(step.input, {'crop': 'Green Gram'});
      expect(step.output, 'plain text');
      final diagnosis = advisory.photoDiagnosis!;
      expect(diagnosis.modelConfidence, 0.93);
      expect(diagnosis.escalationReasons, ['LowMargin', 'HighSeverity']);
      expect(diagnosis.suggestedTreatment, 'Remove infected plants.');
      expect(diagnosis.diseaseOptions!.map((option) => option.key), ['yellow_mosaic', 'other']);
    });

    test('an officer’s own treatment replaces the AI advice only when they rejected it', () {
      bool replaces(String status, String? treatment) => Advisory.fromJson(
        farmerAdvisoryJson(status: status, extra: {'officerTreatment': treatment}),
      ).replacesAiRecommendation;
      expect(replaces('Rejected', 'Use a different spray.'), isTrue);
      expect(replaces('Rejected', null), isFalse);
      expect(replaces('Rejected', ''), isFalse);
      expect(replaces('Approved', 'Use a different spray.'), isFalse);
      expect(replaces('Preliminary', 'Use a different spray.'), isFalse);
    });
  });
}
