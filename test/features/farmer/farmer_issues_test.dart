import 'dart:async';

import 'package:agrilink_mobile/app/router/app_router.dart';
import 'package:agrilink_mobile/app/router/app_routes.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:agrilink_mobile/features/issues/application/advisories.dart';
import 'package:agrilink_mobile/shared/media/photo_picker.dart';
import 'package:agrilink_mobile/shared/permissions/permissions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';
import '../issues/issue_fixtures.dart';
import 'farmer_backend.dart';

/// Stands in for the camera and gallery.
class FakePhotoPicker implements PhotoPicker {
  final List<PhotoSource> picked = [];

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    picked.add(source);
    return PickedPhoto(tinyPng);
  }
}

String currentPath(TestApp app) =>
    app.container.read(routerProvider).routerDelegate.currentConfiguration.uri.path;

Map<String, Object?> issue7() => issueJson();

Map<String, Object?> issue8() => issueJson(
  id: 8,
  title: 'Tomato blight',
  severity: 'Medium',
  status: 'Resolved',
  advisoryId: 22,
  advisoryStatus: 'Approved',
  hasPhoto: false,
  reviewNote: 'Spray neem oil.',
  createdAt: '2026-09-18T08:00:00',
);

Map<String, Object?> issue9() => issueJson(
  id: 9,
  title: 'Wilting plants',
  severity: 'Low',
  advisoryId: 23,
  advisoryStatus: 'Preliminary',
);

void main() {
  late GatedApi api;
  late FarmerBackend backend;
  late FakePhotoPicker picker;

  setUp(() {
    api = GatedApi();
    picker = FakePhotoPicker();
    backend = FarmerBackend(
      api,
      issues: [issue9(), issue8(), issue7()],
      advisories: {
        21: farmerAdvisoryJson(status: 'Draft'),
        22: farmerAdvisoryJson(
          extra: {
            'reviewedByName': 'K. Silva',
            'reviewedAt': '2026-09-19T10:00:00Z',
            'reviewNote': 'Spray neem oil.',
            'photos': [
              {'imageId': 9, 'url': '/api/issues/8/images/9', 'width': 800, 'height': 600},
            ],
          },
        ),
        23: farmerAdvisoryJson(status: 'Preliminary'),
      },
    );
  });

  List<Override> overrides() => [
    issuePhotoProvider.overrideWith((ref, url) async => tinyPng),
    photoPickerProvider.overrideWithValue(picker),
  ];

  Future<TestApp> openIssues(
    WidgetTester tester, {
    FakePermissions? permissions,
    String language = 'en',
    Size screen = const Size(390, 844),
  }) async {
    final app = await pumpFarmer(
      tester,
      backend,
      overrides: overrides(),
      permissions: permissions,
      language: language,
      screen: screen,
    );
    await tester.tap(find.byKey(const Key('nav-/issues/mine')));
    await tester.pumpAndSettle();
    return app;
  }

  group('My Issues', () {
    testWidgets('lists the issues with their severity, status, photo and date', (tester) async {
      final app = await openIssues(tester);
      expect(currentPath(app), AppRoutes.myIssues);
      expect(find.text('Wilting plants'), findsOneWidget);
      expect(find.text('Tomato blight'), findsOneWidget);
      expect(find.text('Yellow leaves'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Awaiting review'), findsNWidgets(2));
      expect(find.text('Resolved'), findsOneWidget);
      // Preliminary advice is flagged on the card.
      expect(find.text('Preliminary'), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_outlined), findsNWidgets(2));
    });

    testWidgets('an empty list invites the farmer to report an issue', (tester) async {
      backend.issues.clear();
      final app = await openIssues(tester);
      expect(find.textContaining("You haven't reported any crop issues yet"), findsOneWidget);
      // One button, not two.
      expect(find.byKey(const Key('report-issue')), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Report an Issue'));
      await tester.pumpAndSettle();
      expect(currentPath(app), '/issues/mine/new');
    });

    testWidgets('a failed load can be tried again', (tester) async {
      backend.api.offline('GET', '/api/issues/mine');
      await openIssues(tester);
      expect(find.textContaining("Can't reach the server"), findsOneWidget);
      backend.api.on(
        'GET',
        '/api/issues/mine',
        (_) => FakeResponse(200, {
          'items': [issue7()],
          'page': 1,
          'pageSize': 20,
          'totalCount': 1,
          'totalPages': 1,
        }),
      );
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Yellow leaves'), findsOneWidget);
    });

    testWidgets('loads more issues while scrolling and shows new ones on pull down', (
      tester,
    ) async {
      backend.issues.addAll([
        for (var i = 0; i < 45; i++) issueJson(id: 100 + i, title: 'Older issue $i'),
      ]);
      await openIssues(tester);
      await tester.scrollUntilVisible(find.text('Older issue 44'), 500);
      expect(find.text('Older issue 44'), findsOneWidget);
      final pages = backend.api.requests
          .where((r) => r.path == '/api/issues/mine')
          .map((r) => r.query['page']);
      expect(pages, containsAll(['1', '2', '3']));

      // A new issue appears on the server. Scroll to the top, then pull down from there, which
      // reloads from page 1 (the indicator only starts a pull that begins at the very top).
      backend.issues.insert(0, issueJson(id: 200, title: 'Brand new issue'));
      await tester.drag(find.byType(ListView), const Offset(0, 100000));
      await tester.pumpAndSettle();
      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Brand new issue'), findsOneWidget);
    });
  });

  group('issue detail', () {
    testWidgets('an issue still being reviewed says so and has no advice yet', (tester) async {
      final app = await openIssues(tester);
      await tester.tap(find.text('Yellow leaves'));
      await tester.pumpAndSettle();

      expect(currentPath(app), '/issues/mine/7');
      expect(find.text('Issue details'), findsOneWidget);
      expect(find.text('The lower leaves are turning yellow.'), findsOneWidget);
      expect(find.text('Green Gram · MI 5'), findsOneWidget);
      expect(find.textContaining('An officer is reviewing your issue'), findsOneWidget);
      expect(find.byKey(const Key('view-advisory')), findsNothing);
      expect(find.text('Photo attached'), findsOneWidget);
    });

    testWidgets('a decided issue shows the officer’s note, the photo and the advice', (
      tester,
    ) async {
      final app = await openIssues(tester);
      await tester.tap(find.text('Tomato blight'));
      await tester.pumpAndSettle();

      expect(find.text("Officer's note"), findsOneWidget);
      expect(find.text('Spray neem oil.'), findsOneWidget);
      // The photo comes with the advisory.
      expect(find.text('Photos'), findsOneWidget);
      expect(find.byType(Image), findsWidgets);

      await tester.tapVisible(find.byKey(const Key('view-advisory')));
      expect(find.text('Your advisory is ready'), findsOneWidget);
      expect(find.text('Apply a balanced fertiliser.'), findsOneWidget);

      // It was pushed, so Back returns to the issue.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Issue details'), findsOneWidget);
      expect(currentPath(app), '/issues/mine/8');
    });

    testWidgets('an issue opened from a saved link is looked up', (tester) async {
      final app = await pumpFarmer(tester, backend, overrides: overrides());
      app.container.read(routerProvider).go('/issues/mine/8');
      await tester.pumpAndSettle();
      expect(find.text('Tomato blight'), findsOneWidget);
    });

    testWidgets('a link to an issue that is not the farmer’s says so', (tester) async {
      final app = await pumpFarmer(tester, backend, overrides: overrides());
      app.container.read(routerProvider).go('/issues/mine/999');
      await tester.pumpAndSettle();
      expect(find.text("We couldn't find this issue."), findsOneWidget);
    });
  });

  group('the advisory screen', () {
    Future<TestApp> openAdvisory(WidgetTester tester, int id) async {
      final app = await pumpFarmer(tester, backend, overrides: overrides());
      app.container.read(routerProvider).go('/advisories/$id');
      await tester.pumpAndSettle();
      return app;
    }

    testWidgets('a draft is not released, so the page says the issue is being reviewed', (
      tester,
    ) async {
      await openAdvisory(tester, 21);
      expect(
        find.text("This advisory isn't available yet — it may still be awaiting officer review."),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsNothing);

      // Once an officer releases it, pulling down shows it.
      backend.advisories[21] = farmerAdvisoryJson(status: 'Preliminary');
      await tester.fling(find.byType(SingleChildScrollView).first, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Preliminary advice'), findsOneWidget);
    });

    testWidgets('preliminary advice is labelled as not yet confirmed', (tester) async {
      await openAdvisory(tester, 23);
      expect(find.text('Preliminary advice'), findsOneWidget);
      expect(find.textContaining('An agricultural officer will confirm it'), findsOneWidget);
    });

    testWidgets('an approved advisory shows the advice and the reviewer', (tester) async {
      await openAdvisory(tester, 22);
      expect(find.text('Your advisory is ready'), findsOneWidget);
      expect(find.text('87% confidence'), findsOneWidget);
      expect(find.textContaining('Reviewed by K. Silva'), findsOneWidget);
    });

    testWidgets('a server error can be tried again', (tester) async {
      backend.api.on('GET', '/api/advisories/22', (_) => const FakeResponse(500));
      await openAdvisory(tester, 22);
      expect(find.text('Try again'), findsOneWidget);
      backend.api.on('GET', '/api/advisories/22', (_) => FakeResponse(200, backend.advisories[22]));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Your advisory is ready'), findsOneWidget);
    });
  });

  group('reporting an issue', () {
    Future<void> openForm(WidgetTester tester, {FakePermissions? permissions}) async {
      await openIssues(tester, permissions: permissions);
      await tester.tap(find.byKey(const Key('report-issue')));
      await tester.pumpAndSettle();
    }

    Future<void> chooseCrop(WidgetTester tester) async {
      await tester.tapVisible(find.byKey(const Key('issue-crop')));
      await tester.tap(find.byKey(const Key('issue-crop-100')));
      await tester.pumpAndSettle();
    }

    Future<void> fillIn(WidgetTester tester) async {
      await chooseCrop(tester);
      await tester.fill(find.byKey(const Key('issue-title')), '  Holes in the leaves ');
      await tester.fill(find.byKey(const Key('issue-description')), 'Small holes, spreading fast.');
    }

    testWidgets('checks the form before sending anything', (tester) async {
      await openForm(tester);
      await tester.tapVisible(find.byKey(const Key('issue-submit')));
      expect(find.text('Choose the crop with the problem'), findsOneWidget);
      expect(find.text('Title is required'), findsOneWidget);
      expect(find.text('Description is required'), findsOneWidget);
      expect(api.lastTo('POST', '/api/issues'), isNull);
    });

    testWidgets('a farmer with no crops is sent to plant one first', (tester) async {
      backend.crops.clear();
      final app = await openIssues(tester);
      await tester.tap(find.byKey(const Key('report-issue')));
      await tester.pumpAndSettle();
      expect(find.text('You have no crops to report an issue for yet.'), findsOneWidget);
      await tester.tap(find.text('Go to my farms'));
      await tester.pumpAndSettle();
      expect(currentPath(app), AppRoutes.farms);
    });

    testWidgets('sends the report without a photo as JSON, then opens the issue', (tester) async {
      final app = await openIssues(tester);
      await tester.tap(find.byKey(const Key('report-issue')));
      await tester.pumpAndSettle();
      await fillIn(tester);
      await tester.tap(find.byKey(const Key('issue-severity')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('High').last);
      await tester.pumpAndSettle();
      await tester.tapVisible(find.byKey(const Key('issue-submit')));

      expect(api.lastTo('POST', '/api/issues')!.json, {
        'cropId': 100,
        'title': 'Holes in the leaves',
        'description': 'Small holes, spreading fast.',
        'severity': 'High',
      });
      expect(currentPath(app), '/issues/mine/50');
      expect(find.text('Holes in the leaves'), findsOneWidget);
      expect(find.text('Issue reported.'), findsOneWidget);
      expect(find.textContaining('An officer is reviewing your issue'), findsOneWidget);
    });

    testWidgets('the new issue is at the top of My Issues when the farmer goes back', (
      tester,
    ) async {
      await openForm(tester);
      await fillIn(tester);
      await tester.tapVisible(find.byKey(const Key('issue-submit')));

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Holes in the leaves'), findsOneWidget);
    });

    testWidgets('while the API analyses the report, it says so and can’t be sent twice', (
      tester,
    ) async {
      final app = await openIssues(tester);
      await tester.tap(find.byKey(const Key('report-issue')));
      await tester.pumpAndSettle();
      await fillIn(tester);

      api.gate = Completer<void>();
      await tester.ensureVisible(find.byKey(const Key('issue-submit')));
      await tester.tap(find.byKey(const Key('issue-submit')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Analysing your crop…'), findsOneWidget);
      expect(find.textContaining('This can take up to a minute'), findsOneWidget);

      // A second tap goes to the overlay, not the button, so nothing more is sent.
      await tester.tap(find.byKey(const Key('analysing')), warnIfMissed: false);
      await tester.pump();
      expect(api.reportAttempts, 1);

      api.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Analysing your crop…'), findsNothing);
      expect(currentPath(app), '/issues/mine/50');
    });

    testWidgets('Android’s back button does nothing while the report is being analysed', (
      tester,
    ) async {
      final app = await openIssues(tester);
      await tester.tap(find.byKey(const Key('report-issue')));
      await tester.pumpAndSettle();
      await fillIn(tester);

      api.gate = Completer<void>();
      await tester.ensureVisible(find.byKey(const Key('issue-submit')));
      await tester.tap(find.byKey(const Key('issue-submit')));
      await tester.pump(const Duration(seconds: 1));

      await tester.pageBack();
      await tester.pump();
      expect(currentPath(app), '/issues/mine/new');
      expect(find.text('Analysing your crop…'), findsOneWidget);

      api.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('advice released straight away opens the advisory', (tester) async {
      backend.newIssueAdvisoryStatus = 'Preliminary';
      final app = await openIssues(tester);
      await tester.tap(find.byKey(const Key('report-issue')));
      await tester.pumpAndSettle();
      await fillIn(tester);
      await tester.tapVisible(find.byKey(const Key('issue-submit')));

      expect(find.text('Preliminary advice'), findsOneWidget);
      // Pushed on top of the list, so Back returns to it, and it now has the new issue.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(currentPath(app), AppRoutes.myIssues);
      expect(find.text('Holes in the leaves'), findsOneWidget);
    });

    group('with a photo', () {
      Future<void> addPhoto(WidgetTester tester, {String from = 'Choose from gallery'}) async {
        await tester.tapVisible(find.byKey(const Key('add-photo')));
        await tester.tap(find.text(from));
        await tester.pumpAndSettle();
      }

      testWidgets('shows a preview that can be removed or changed', (tester) async {
        await openForm(tester);
        expect(find.byKey(const Key('photo-preview')), findsNothing);

        await addPhoto(tester);
        expect(picker.picked, [PhotoSource.gallery]);
        expect(find.byKey(const Key('photo-preview')), findsOneWidget);
        expect(find.byKey(const Key('add-photo')), findsNothing);

        await tester.tapVisible(find.byKey(const Key('remove-photo')));
        expect(find.byKey(const Key('photo-preview')), findsNothing);
        expect(find.byKey(const Key('add-photo')), findsOneWidget);

        await addPhoto(tester, from: 'Take a photo');
        await tester.tapVisible(find.byKey(const Key('change-photo')));
        await tester.tap(find.text('Choose from gallery'));
        await tester.pumpAndSettle();
        expect(picker.picked, [PhotoSource.gallery, PhotoSource.camera, PhotoSource.gallery]);
        expect(find.byKey(const Key('photo-preview')), findsOneWidget);
      });

      testWidgets('sends the fields and the photo as a multipart request', (tester) async {
        final app = await openIssues(tester);
        await tester.tap(find.byKey(const Key('report-issue')));
        await tester.pumpAndSettle();
        await fillIn(tester);
        await addPhoto(tester);
        await tester.tapVisible(find.byKey(const Key('issue-submit')));

        expect(api.lastTo('POST', '/api/issues'), isNull);
        final form = api.lastTo('POST', '/api/issues/with-photo')!.body! as FormData;
        expect(Map.fromEntries(form.fields), {
          'cropId': '100',
          'title': 'Holes in the leaves',
          'description': 'Small holes, spreading fast.',
          'severity': 'Medium',
        });
        expect(form.files.single.key, 'photo');
        expect(form.files.single.value.length, tinyPng.length);
        expect(currentPath(app), '/issues/mine/50');
        expect(find.text('Photo attached'), findsOneWidget);
      });

      testWidgets('the camera is only asked for when the farmer chooses it', (tester) async {
        final permissions = FakePermissions(PermissionResult.denied);
        await openForm(tester, permissions: permissions);
        // Opening the form and choosing from the gallery ask for nothing.
        await addPhoto(tester);
        expect(permissions.requested, isEmpty);
        await tester.tapVisible(find.byKey(const Key('remove-photo')));

        await tester.tapVisible(find.byKey(const Key('add-photo')));
        await tester.tap(find.text('Take a photo'));
        await tester.pumpAndSettle();
        expect(find.text('Allow camera access'), findsOneWidget);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(permissions.requested, [AppPermission.camera]);
        // Refused: no photo, and the farmer is told they can use the gallery.
        expect(find.byKey(const Key('photo-preview')), findsNothing);
        expect(find.textContaining('choose one from your gallery'), findsOneWidget);
      });

      testWidgets('a camera that is turned off for good offers the settings', (tester) async {
        final permissions = FakePermissions(PermissionResult.permanentlyDenied);
        await openForm(tester, permissions: permissions);
        await tester.tapVisible(find.byKey(const Key('add-photo')));
        await tester.tap(find.text('Take a photo'));
        await tester.pumpAndSettle();
        expect(find.textContaining('turned off for AgriLink'), findsOneWidget);
        await tester.tap(find.text('Open settings'));
        await tester.pumpAndSettle();
        expect(permissions.settingsOpened, 1);
        expect(find.byKey(const Key('photo-preview')), findsNothing);
      });
    });

    group('when it fails', () {
      Future<void> submitFilledForm(WidgetTester tester, {bool photo = false}) async {
        await openForm(tester);
        await fillIn(tester);
        if (photo) {
          await tester.tapVisible(find.byKey(const Key('add-photo')));
          await tester.tap(find.text('Choose from gallery'));
          await tester.pumpAndSettle();
        }
        await tester.tapVisible(find.byKey(const Key('issue-submit')));
      }

      void expectNothingLost(WidgetTester tester, {bool photo = false}) {
        expect(find.text('Analysing your crop…'), findsNothing);
        expect(
          tester.widget<TextFormField>(find.byKey(const Key('issue-title'))).controller!.text,
          '  Holes in the leaves ',
        );
        expect(
          tester.widget<TextFormField>(find.byKey(const Key('issue-description'))).controller!.text,
          'Small holes, spreading fast.',
        );
        expect(find.byKey(const Key('photo-preview')), photo ? findsOneWidget : findsNothing);
      }

      testWidgets('a photo the API can’t use keeps everything and says why', (tester) async {
        api.on(
          'POST',
          '/api/issues/with-photo',
          (_) => const FakeResponse(400, {'message': 'Not an image.'}),
        );
        await submitFilledForm(tester, photo: true);
        expect(
          find.text("The photo couldn't be used. Try a different photo, or report without one."),
          findsWidgets,
        );
        expectNothingLost(tester, photo: true);
      });

      testWidgets('photo storage being down says so', (tester) async {
        api.on(
          'POST',
          '/api/issues/with-photo',
          (_) => const FakeResponse(503, {'message': 'Storage down.'}),
        );
        await submitFilledForm(tester, photo: true);
        expect(find.textContaining("couldn't be uploaded right now"), findsWidgets);
        expectNothingLost(tester, photo: true);
      });

      testWidgets('no connection keeps everything and can be retried', (tester) async {
        api.offline('POST', '/api/issues');
        await submitFilledForm(tester);
        expect(find.textContaining("Can't reach the server"), findsWidgets);
        expectNothingLost(tester);

        // Back online, once the message at the bottom has cleared: the same form goes through.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        api.on(
          'POST',
          '/api/issues',
          (_) => FakeResponse(201, issueJson(id: 77, title: 'Holes in the leaves')),
        );
        await tester.tapVisible(find.byKey(const Key('issue-submit')));
        expect(find.text('Issue reported.'), findsOneWidget);
      });

      testWidgets('a timeout warns that the report may have gone through', (tester) async {
        api.timeOutReports = true;
        await submitFilledForm(tester);
        expect(find.textContaining('It may still have gone through'), findsWidgets);
        expectNothingLost(tester);
      });

      testWidgets('any other error is a plain message', (tester) async {
        api.on('POST', '/api/issues', (_) => const FakeResponse(500));
        await submitFilledForm(tester);
        expect(find.text('Could not report the issue. Try again.'), findsWidgets);
        expectNothingLost(tester);
      });
    });

    testWidgets('from a crop, the crop is already chosen and Back returns to the crop', (
      tester,
    ) async {
      final app = await pumpFarmer(tester, backend, overrides: overrides());
      app.container.read(routerProvider).go('/farms/1/fields/10/crops/100');
      await tester.pumpAndSettle();
      await tester.tapVisible(find.byKey(const Key('report-crop-issue')));
      // Pushed on top of the crop, so the router's own path is still the crop's.
      expect(find.text('Report an Issue'), findsWidgets);
      expect(find.text('Green Gram · MI 5'), findsOneWidget);
      expect(find.text('North Field · Green Acres'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(currentPath(app), '/farms/1/fields/10/crops/100');
    });
  });

  group('access and small screens', () {
    testWidgets('a buyer cannot open the farmer’s issue pages', (tester) async {
      final app = await pumpAgriLink(
        tester,
        api: backend.api
          ..on('GET', '/api/users/me', (_) => FakeResponse(200, profileJson(Role.buyer))),
        session: Session(token: fakeJwt(), role: Role.buyer),
      );
      for (final path in ['/issues/mine', '/issues/mine/new', '/issues/mine/7', '/advisories/22']) {
        app.container.read(routerProvider).go(path);
        await tester.pumpAndSettle();
        expect(currentPath(app), AppRoutes.marketplace, reason: path);
      }
    });

    for (final language in ['si', 'ta']) {
      testWidgets('every issue screen fits in $language with large text', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final app = await openIssues(tester, language: language, screen: const Size(320, 640));
        void noOverflow(String where) {
          final error = tester.takeException();
          final detail = error is FlutterError
              ? error.diagnostics.map((node) => node.toString()).take(12).join(' | ')
              : '';
          expect(error, isNull, reason: '$language: $where $detail');
        }

        noOverflow('my issues');
        app.container.read(routerProvider).go('/issues/mine/8');
        await tester.pumpAndSettle();
        noOverflow('issue detail');
        app.container.read(routerProvider).go('/advisories/22');
        await tester.pumpAndSettle();
        noOverflow('advisory');
        app.container.read(routerProvider).go('/advisories/23');
        await tester.pumpAndSettle();
        noOverflow('preliminary advisory');
        app.container.read(routerProvider).go('/advisories/21');
        await tester.pumpAndSettle();
        noOverflow('unavailable advisory');
        app.container.read(routerProvider).go('/issues/mine/new');
        await tester.pumpAndSettle();
        noOverflow('report form');
        await tester.tapVisible(find.byKey(const Key('issue-submit')));
        await tester.pumpAndSettle();
        noOverflow('report form errors');
      });
    }
  });
}
