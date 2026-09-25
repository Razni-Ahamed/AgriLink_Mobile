import 'dart:convert';
import 'dart:typed_data';

import 'package:agrilink_mobile/core/api/api_exception.dart';
import 'package:agrilink_mobile/features/issues/application/advisories.dart';
import 'package:agrilink_mobile/features/issues/data/advisory.dart';
import 'package:agrilink_mobile/features/issues/data/issue_enums.dart';
import 'package:agrilink_mobile/features/issues/presentation/widgets/advisory_view.dart';
import 'package:agrilink_mobile/features/issues/presentation/widgets/issue_badges.dart';
import 'package:agrilink_mobile/features/issues/presentation/widgets/issue_photo_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'issue_fixtures.dart';

/// A 1×1 PNG, so `Image.memory` has something real to decode.
final Uint8List tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Advisory advisory({String status = 'Approved', Map<String, Object?> extra = const {}}) =>
    Advisory.fromJson(farmerAdvisoryJson(status: status, extra: extra));

Future<void> pumpView(
  WidgetTester tester,
  Advisory advisory, {
  AdvisoryAudience audience = AdvisoryAudience.farmer,
}) => tester.pumpApp(
  SingleChildScrollView(
    child: AdvisoryView(advisory: advisory, audience: audience),
  ),
  overrides: [issuePhotoProvider.overrideWith((ref, url) async => tinyPng)],
);

void main() {
  group('badges', () {
    testWidgets('use the website’s words for severity, issue status, advisory status and risk', (
      tester,
    ) async {
      await tester.pumpApp(
        const Column(
          children: [
            SeverityBadge(IssueSeverity.high),
            IssueStatusBadge(IssueStatus.awaitingReview),
            AdvisoryStatusBadge(AdvisoryStatus.preliminary),
            RiskBadge(RiskLevel.medium),
          ],
        ),
      );
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Awaiting review'), findsOneWidget);
      expect(find.text('Preliminary'), findsOneWidget);
      expect(find.text('Risk: Medium'), findsOneWidget);
    });
  });

  group('AdvisoryView for a farmer', () {
    testWidgets('an approved advisory shows the advice and who approved it', (tester) async {
      await pumpView(
        tester,
        advisory(
          extra: {
            'reviewedByName': 'K. Silva',
            'reviewedAt': '2026-09-21T10:00:00Z',
            'reviewNote': 'Looks right.',
          },
        ),
      );
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Risk: Medium'), findsOneWidget);
      expect(find.text('87% confidence'), findsOneWidget);
      expect(find.text('Apply a balanced fertiliser.'), findsOneWidget);
      expect(find.textContaining('Reviewed by K. Silva'), findsOneWidget);
      expect(find.text('Looks right.'), findsOneWidget);
      expect(find.text('Preliminary advice'), findsNothing);
    });

    testWidgets('a preliminary advisory is clearly not final', (tester) async {
      await pumpView(tester, advisory(status: 'Preliminary'));
      expect(find.text('Preliminary advice'), findsOneWidget);
      expect(find.textContaining('An agricultural officer will confirm it'), findsOneWidget);
      expect(find.text('Preliminary'), findsOneWidget);
    });

    testWidgets('a rejected advisory shows the officer’s note', (tester) async {
      await pumpView(
        tester,
        advisory(
          status: 'Rejected',
          extra: {
            'reviewedByName': 'K. Silva',
            'reviewedAt': '2026-09-21T10:00:00Z',
            'reviewNote': 'Not enough detail.',
          },
        ),
      );
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Not enough detail.'), findsOneWidget);
    });

    testWidgets('the officer’s own advice replaces the AI advice they rejected', (tester) async {
      await pumpView(
        tester,
        advisory(status: 'Rejected', extra: {'officerTreatment': 'Spray neem oil weekly.'}),
      );
      expect(find.text("Officer's advice"), findsOneWidget);
      expect(find.text('Spray neem oil weekly.'), findsOneWidget);
      expect(find.text('Apply a balanced fertiliser.'), findsNothing);
      expect(find.text('Recommendation'), findsNothing);
    });

    testWidgets('an approved advisory with officer advice shows both', (tester) async {
      await pumpView(tester, advisory(extra: {'officerTreatment': 'Spray neem oil weekly.'}));
      expect(find.text('Spray neem oil weekly.'), findsOneWidget);
      expect(find.text('Apply a balanced fertiliser.'), findsOneWidget);
    });

    testWidgets('shows the diagnosis: the photo’s guess, or the officer’s confirmed one', (
      tester,
    ) async {
      await pumpView(
        tester,
        advisory(
          extra: {
            'photoDiagnosis': {'diseaseKey': 'mosaic', 'diseaseName': 'Yellow Mosaic'},
          },
        ),
      );
      expect(find.text('Identified from the photo: Yellow Mosaic'), findsOneWidget);

      await pumpView(
        tester,
        advisory(
          extra: {
            'photoDiagnosis': {'diseaseKey': 'mosaic', 'diseaseName': 'Yellow Mosaic'},
            'confirmedDiseaseName': 'Leaf Curl',
          },
        ),
      );
      expect(find.text("Officer's diagnosis: Leaf Curl"), findsOneWidget);
      expect(find.textContaining('Identified from the photo'), findsNothing);
    });

    testWidgets('names the crop, the reporter and the district', (tester) async {
      await pumpView(tester, advisory());
      expect(find.text('Green Gram · MI 5'), findsOneWidget);
      expect(find.text('The lower leaves are turning yellow.'), findsOneWidget);
      expect(find.textContaining('Reported by Nimal Perera · Kandy'), findsOneWidget);
    });

    testWidgets('an unknown reporter is named as such', (tester) async {
      await pumpView(tester, advisory(extra: {'reporterName': ''}));
      expect(find.textContaining('Reported by Unknown farmer'), findsOneWidget);
    });
  });

  group('AdvisoryView for a reviewer', () {
    testWidgets('sees the AI advice alongside the officer’s own', (tester) async {
      await pumpView(
        tester,
        advisory(status: 'Rejected', extra: {'officerTreatment': 'Spray neem oil weekly.'}),
        audience: AdvisoryAudience.reviewer,
      );
      expect(find.text('Spray neem oil weekly.'), findsOneWidget);
      expect(find.text('Apply a balanced fertiliser.'), findsOneWidget);
    });

    testWidgets('does not show the farmer’s preliminary notice', (tester) async {
      await pumpView(tester, advisory(status: 'Preliminary'), audience: AdvisoryAudience.reviewer);
      expect(find.text('Preliminary advice'), findsNothing);
    });
  });

  group('IssuePhotoGallery', () {
    const photos = [
      IssuePhoto(imageId: 9, url: '/api/issues/7/images/9', width: 1200, height: 1600),
    ];

    testWidgets('shows nothing without photos', (tester) async {
      await tester.pumpApp(const IssuePhotoGallery(photos: []));
      expect(find.text('Photos'), findsNothing);
    });

    testWidgets('loads each photo through the API', (tester) async {
      final requested = <String>[];
      await tester.pumpApp(
        const IssuePhotoGallery(photos: photos),
        overrides: [
          issuePhotoProvider.overrideWith((ref, url) async {
            requested.add(url);
            return tinyPng;
          }),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('Photos'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(requested, ['/api/issues/7/images/9']);
    });

    testWidgets('a photo that cannot be loaded says so and can be retried', (tester) async {
      var attempts = 0;
      await tester.pumpApp(
        const IssuePhotoGallery(photos: photos),
        overrides: [
          issuePhotoProvider.overrideWith((ref, url) async {
            attempts++;
            if (attempts == 1) {
              throw const ApiException(ApiErrorKind.notFound, statusCode: 404);
            }
            return tinyPng;
          }),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('Photo unavailable'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('Photo unavailable'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('tapping a photo opens it full screen, where it can be zoomed and closed', (
      tester,
    ) async {
      await tester.pumpApp(
        const IssuePhotoGallery(photos: photos),
        overrides: [issuePhotoProvider.overrideWith((ref, url) async => tinyPng)],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('photo-9')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('photo-viewer')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('photo-viewer')), findsNothing);
    });
  });
}
