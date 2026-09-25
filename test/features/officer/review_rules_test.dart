import 'package:agrilink_mobile/features/issues/data/advisory.dart';
import 'package:agrilink_mobile/features/officer/application/review_rules.dart';
import 'package:agrilink_mobile/features/officer/application/trace_format.dart';
import 'package:flutter_test/flutter_test.dart';

import 'officer_fixtures.dart';

ReviewProblems check(
  Advisory advisory,
  ReviewAction action, {
  String treatment = '',
  String? disease,
}) => checkReview(advisory: advisory, action: action, treatment: treatment, diseaseKey: disease);

void main() {
  group('an advisory without a photo diagnosis', () {
    final advisory = reviewerAdvisory();

    test('needs nothing to approve or reject, not even a note', () {
      expect(check(advisory, ReviewAction.approve).any, isFalse);
      expect(check(advisory, ReviewAction.reject).any, isFalse);
    });
  });

  group('approving (confirming) a photo diagnosis', () {
    test('a draft needs the officer\'s treatment, because the farmer has had no advice', () {
      final draft = reviewerAdvisory(photo: true);
      expect(check(draft, ReviewAction.approve).needsTreatment, isTrue);
      expect(check(draft, ReviewAction.approve, treatment: '   ').needsTreatment, isTrue);
      expect(check(draft, ReviewAction.approve, treatment: 'Spray it').any, isFalse);
    });

    test('preliminary advice has already gone out, so no treatment is needed', () {
      final preliminary = reviewerAdvisory(status: 'Preliminary', photo: true);
      expect(check(preliminary, ReviewAction.approve).any, isFalse);
    });

    test('choosing a different disease while approving points to Correct diagnosis', () {
      final draft = reviewerAdvisory(photo: true);
      final problems = check(draft, ReviewAction.approve, treatment: 'x', disease: 'rust');
      expect(problems.useCorrectToChange, isTrue);
      expect(check(draft, ReviewAction.approve, treatment: 'x', disease: 'leaf_spot').any, isFalse);
    });
  });

  group('rejecting (correcting) a photo diagnosis', () {
    final advisory = reviewerAdvisory(status: 'Preliminary', photo: true);

    test('needs the correct disease and a treatment', () {
      final problems = check(advisory, ReviewAction.reject);
      expect(problems.needsDisease, isTrue);
      expect(problems.needsTreatment, isTrue);
    });

    test('is complete with both', () {
      expect(
        check(advisory, ReviewAction.reject, treatment: 'Spray', disease: 'rust').any,
        isFalse,
      );
    });

    test('a missing disease is reported on its own', () {
      final problems = check(advisory, ReviewAction.reject, treatment: 'Spray');
      expect(problems.needsDisease, isTrue);
      expect(problems.needsTreatment, isFalse);
    });
  });

  test('only a draft or preliminary advisory can be reviewed', () {
    expect(canReview(reviewerAdvisory()), isTrue);
    expect(canReview(reviewerAdvisory(status: 'Preliminary')), isTrue);
    expect(canReview(reviewerAdvisory(status: 'Approved')), isFalse);
    expect(canReview(reviewerAdvisory(status: 'Rejected')), isFalse);
  });

  group('buildReviewRequest', () {
    final plain = reviewerAdvisory();
    final photo = reviewerAdvisory(photo: true);

    test('leaves blank fields out and trims the rest', () {
      final request = buildReviewRequest(
        advisory: plain,
        action: ReviewAction.approve,
        note: '  Looks right  ',
        treatment: '   ',
        diseaseKey: null,
      );
      expect(request.toJson(), {'note': 'Looks right'});
    });

    test('an empty review is an empty body', () {
      final request = buildReviewRequest(
        advisory: plain,
        action: ReviewAction.reject,
        note: '',
        treatment: '',
        diseaseKey: null,
      );
      expect(request.toJson(), isEmpty);
    });

    test('the disease is only sent when correcting a photo diagnosis', () {
      final approve = buildReviewRequest(
        advisory: photo,
        action: ReviewAction.approve,
        note: '',
        treatment: 'Spray',
        diseaseKey: 'leaf_spot',
      );
      expect(approve.toJson(), {'treatment': 'Spray'});

      final reject = buildReviewRequest(
        advisory: photo,
        action: ReviewAction.reject,
        note: 'Wrong disease',
        treatment: 'Spray',
        diseaseKey: 'rust',
      );
      expect(reject.toJson(), {
        'note': 'Wrong disease',
        'treatment': 'Spray',
        'diseaseKey': 'rust',
      });

      final noPhoto = buildReviewRequest(
        advisory: plain,
        action: ReviewAction.reject,
        note: '',
        treatment: '',
        diseaseKey: 'rust',
      );
      expect(noPhoto.toJson(), isEmpty);
    });
  });

  group('trace formatting', () {
    test('agent names lose the Agent suffix and split into words', () {
      expect(agentDisplayName('CropAnalysisAgent'), 'Crop Analysis');
      expect(agentDisplayName('PlannerAgent'), 'Planner');
      expect(agentDisplayName('Agent'), 'Agent');
      expect(agentDisplayName('Custom'), 'Custom');
    });

    test('keys become labels', () {
      expect(humanizeKey('avgTemperatureC'), 'Avg Temperature C');
      expect(humanizeKey('UseCropAgent'), 'Use Crop Agent');
      expect(humanizeKey('score'), 'Score');
      expect(humanizeKey(''), '');
    });

    test('a step\'s duration comes from its start and end, and is absent while running', () {
      AgentStep step({DateTime? end}) => AgentStep(
        agentName: 'WeatherAgent',
        status: 'Completed',
        startedAt: DateTime.utc(2026, 9, 20, 8, 30),
        completedAt: end,
      );
      expect(
        stepDuration(step(end: DateTime.utc(2026, 9, 20, 8, 30, 2, 500))),
        const Duration(seconds: 2, milliseconds: 500),
      );
      expect(stepDuration(step()), isNull);
      expect(stepDuration(step(end: DateTime.utc(2026, 9, 20, 8, 29))), isNull);
    });

    test('numbers keep whole values whole and round the rest', () {
      expect(formatTraceNumber(3), '3');
      expect(formatTraceNumber(3.0), '3');
      expect(formatTraceNumber(0.5), '0.50');
      expect(formatTraceNumber(12.3456), '12.35');
    });

    test('long text is cut', () {
      expect(clipTraceText('short'), 'short');
      final clipped = clipTraceText('x' * 700);
      expect(clipped.length, traceTextLimit + 1);
      expect(clipped.endsWith('…'), isTrue);
    });
  });
}
