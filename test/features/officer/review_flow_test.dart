import 'package:agrilink_mobile/app/router/app_router.dart';
import 'package:agrilink_mobile/app/router/app_routes.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:agrilink_mobile/features/officer/presentation/review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';
import '../issues/issue_fixtures.dart';
import 'officer_fixtures.dart';

Map<String, Object?> paged(List<Map<String, Object?>> items) => {
  'items': items,
  'page': 1,
  'pageSize': 20,
  'totalCount': items.length,
  'totalPages': 1,
};

/// An advisory as an officer receives it, with previous issues and a trace.
Map<String, Object?> officerAdvisoryJson({
  String status = 'Draft',
  bool photo = false,
  Map<String, Object?> extra = const {},
}) => farmerAdvisoryJson(
  status: status,
  extra: {
    'requiresApproval': true,
    'previousIssues': [previousIssueJson()],
    'agentTrace': agentTraceJson(),
    'photoDiagnosis': photo ? photoDiagnosisJson() : null,
    ...extra,
  },
);

void main() {
  late FakeApi api;
  late List<Map<String, Object?>> pending;
  late Map<String, Object?> advisory;
  late List<Map<String, Object?>> reviewed;
  late List<Map<String, Object?>> everything;

  setUp(() {
    pending = [
      {...issueJson(), 'reporterName': 'Nimal Perera'},
      {
        ...issueJson(id: 8, advisoryId: 22, advisoryStatus: 'Preliminary', hasPhoto: false),
        'title': 'Curling leaves',
        'reporterName': 'Sunil Silva',
      },
    ];
    advisory = officerAdvisoryJson();
    reviewed = [];
    everything = [];
    api = FakeApi()
      ..on('GET', '/api/issues/pending', (_) => FakeResponse(200, paged(pending)))
      ..on('GET', '/api/issues/reviewed', (_) => FakeResponse(200, paged(reviewed)))
      ..on('GET', '/api/issues', (_) => FakeResponse(200, paged(everything)))
      ..on('GET', '/api/advisories/21', (_) => FakeResponse(200, advisory))
      ..on('GET', '/api/advisories/18', (_) => FakeResponse(200, farmerAdvisoryJson()))
      ..on(
        'GET',
        '/api/officer/metrics',
        (_) => const FakeResponse(200, {
          'district': 'Kandy',
          'departmentName': 'Agriculture',
          'pendingInDistrict': 2,
          'reviewedToday': 0,
          'reviewedTotal': 0,
          'approvedTotal': 0,
          'rejectedTotal': 0,
        }),
      );
  });

  Future<TestApp> open(
    WidgetTester tester,
    Role role,
    String path, {
    String language = 'en',
    Size screen = const Size(390, 844),
  }) async {
    api.on('GET', '/api/users/me', (_) => FakeResponse(200, profileJson(role)));
    final app = await pumpAgriLink(
      tester,
      api: api,
      session: Session(token: fakeJwt(), role: role),
      language: language,
      screen: screen,
    );
    app.container.read(routerProvider).go(path);
    await tester.pumpAndSettle();
    return app;
  }

  Finder key(String name) => find.byKey(Key(name));

  /// Scrolls the review screen's own list (the list underneath it is scrollable too) until
  /// [finder] is built and on screen.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find
          .descendant(of: find.byType(ReviewScreen), matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
  }

  group('Pending Issues', () {
    testWidgets('lists each issue with who reported it and what it needs', (tester) async {
      await open(tester, Role.officer, AppRoutes.pendingIssues);
      expect(find.text('Yellow leaves'), findsOneWidget);
      expect(find.text('Curling leaves'), findsOneWidget);
      expect(find.text('Reported by Nimal Perera · Kandy'), findsOneWidget);
      expect(find.text('Needs your decision'), findsOneWidget);
      expect(find.text('Advice sent — confirm'), findsOneWidget);
      expect(find.text('Showing issues in Kandy'), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
    });

    testWidgets('an admin sees the same list without the district note', (tester) async {
      await open(tester, Role.admin, AppRoutes.pendingIssues);
      expect(find.text('Yellow leaves'), findsOneWidget);
      expect(find.text('Showing issues in Kandy'), findsNothing);
    });

    testWidgets('an empty queue says so', (tester) async {
      pending.clear();
      await open(tester, Role.officer, AppRoutes.pendingIssues);
      expect(find.text('No issues are awaiting review right now.'), findsOneWidget);
    });

    testWidgets('an issue with no advisory yet cannot be opened', (tester) async {
      pending = [issueJson(advisoryId: null, advisoryStatus: null)];
      await open(tester, Role.officer, AppRoutes.pendingIssues);
      await tester.tap(find.text('Yellow leaves'));
      await tester.pumpAndSettle();
      expect(api.requests.where((r) => r.path.startsWith('/api/advisories')), isEmpty);
    });
  });

  group('the review screen', () {
    Future<TestApp> openReview(WidgetTester tester, {Role role = Role.officer}) async {
      final app = await open(tester, role, AppRoutes.pendingIssues);
      await tester.tap(find.text('Yellow leaves'));
      await tester.pumpAndSettle();
      return app;
    }

    testWidgets('shows the advisory, the officer-only context and the controls', (tester) async {
      await openReview(tester);
      expect(api.lastTo('GET', '/api/advisories/21'), isNotNull);
      // The farmer's view of it (Phase 2's advisory widgets).
      expect(find.text('Apply a balanced fertiliser.'), findsOneWidget);
      // Previous issues on this crop.
      await scrollTo(tester, find.text('Previous issues on this crop (1)'));
      expect(find.text('Aphids on leaves'), findsOneWidget);
      // How the AI reached its advice, closed until asked for.
      await scrollTo(tester, find.text('How this was diagnosed'));
      expect(find.text('Planner'), findsNothing);
      // The decision.
      await scrollTo(tester, key('review-approve'));
      expect(key('review-approve'), findsOneWidget);
      expect(key('review-reject'), findsOneWidget);
    });

    testWidgets('approving asks first, sends the decision and returns to a refreshed list', (
      tester,
    ) async {
      var decided = false;
      api.on('POST', '/api/advisories/21/approve', (_) {
        decided = true;
        pending.removeAt(0);
        return FakeResponse(200, officerAdvisoryJson(status: 'Approved'));
      });
      api.on('GET', '/api/issues/pending', (_) => FakeResponse(200, paged(pending)));
      await openReview(tester);
      final listLoadsBefore = api.requests.where((r) => r.path == '/api/issues/pending').length;

      await scrollTo(tester, key('review-note'));
      await tester.fill(key('review-note'), 'Looks right');
      await tester.tapVisible(key('review-approve'));
      expect(decided, isFalse);
      await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Approve')),
      );
      await tester.pumpAndSettle();

      expect(api.lastTo('POST', '/api/advisories/21/approve')!.json, {'note': 'Looks right'});
      // Back on the list, which reloaded without the decided issue.
      expect(find.text('Advice sent — confirm'), findsOneWidget);
      expect(find.text('Yellow leaves'), findsNothing);
      expect(
        api.requests.where((r) => r.path == '/api/issues/pending').length,
        greaterThan(listLoadsBefore),
      );
    });

    testWidgets('a photo diagnosis cannot be confirmed without a treatment', (tester) async {
      advisory = officerAdvisoryJson(photo: true);
      await openReview(tester);
      await scrollTo(tester, find.text('Photo diagnosis'));
      await scrollTo(tester, key('review-approve'));
      await tester.tapVisible(key('review-approve'));

      expect(find.text('Add the treatment the farmer should follow.'), findsOneWidget);
      expect(api.lastTo('POST', '/api/advisories/21/approve'), isNull);
    });

    testWidgets('when someone else decided first it says so and shows the decision', (
      tester,
    ) async {
      api.on(
        'POST',
        '/api/advisories/21/approve',
        (_) => const FakeResponse(400, {
          'message': 'Only advisories awaiting review can be reviewed.',
        }),
      );
      await openReview(tester);
      // By the time the officer presses the button, the advisory has been decided.
      advisory = officerAdvisoryJson(
        status: 'Rejected',
        extra: {'reviewedByName': 'Officer Two', 'reviewedAt': '2026-09-21T09:00:00Z'},
      );
      await scrollTo(tester, key('review-approve'));
      await tester.tapVisible(key('review-approve'));
      await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Approve')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Someone has already reviewed this advisory. It is shown as it stands now.'),
        findsOneWidget,
      );
      expect(key('review-approve'), findsNothing);
      await scrollTo(tester, find.text("This advisory has been reviewed, so it can't be changed."));
    });

    testWidgets('another failure is shown and the officer keeps what they typed', (tester) async {
      api.on(
        'POST',
        '/api/advisories/21/approve',
        (_) => const FakeResponse(500, {'message': 'Something broke.'}),
      );
      await openReview(tester);
      await scrollTo(tester, key('review-note'));
      await tester.fill(key('review-note'), 'My note');
      await tester.tapVisible(key('review-approve'));
      await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Approve')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something broke.'), findsOneWidget);
      expect(tester.widget<TextFormField>(key('review-note')).controller!.text, 'My note');
    });

    testWidgets('a decided advisory is read-only', (tester) async {
      advisory = officerAdvisoryJson(status: 'Approved');
      await openReview(tester);
      await scrollTo(tester, find.text("This advisory has been reviewed, so it can't be changed."));
      expect(key('review-approve'), findsNothing);
    });

    testWidgets('a previous issue opens its own advisory', (tester) async {
      await openReview(tester);
      await scrollTo(tester, key('previous-3'));
      await tester.tap(key('previous-3'));
      await tester.pumpAndSettle();
      expect(api.lastTo('GET', '/api/advisories/18'), isNotNull);
    });

    testWidgets('a failed load shows an error with Try again', (tester) async {
      api.offline('GET', '/api/advisories/21');
      await openReview(tester);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('fits a narrow screen in Sinhala', (tester) async {
      advisory = officerAdvisoryJson(photo: true);
      final app = await open(
        tester,
        Role.officer,
        AppRoutes.pendingIssues,
        language: 'si',
        screen: const Size(320, 640),
      );
      app.container.read(routerProvider).go('${AppRoutes.pendingIssues}/21');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('My Reviews', () {
    testWidgets('shows the outcome and when it was decided', (tester) async {
      reviewed = [
        {
          ...issueJson(status: 'Resolved', advisoryStatus: 'Approved'),
          'reporterName': 'Nimal Perera',
          'reviewedAt': '2026-09-21T12:00:00Z',
          'reviewNote': 'Apply it weekly.',
        },
        {
          ...issueJson(id: 9, status: 'Rejected', advisoryId: 23, advisoryStatus: 'Rejected'),
          'title': 'White spots',
          'reviewedAt': '2026-09-22T12:00:00Z',
        },
      ];
      await open(tester, Role.officer, AppRoutes.reviewedIssues);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Apply it weekly.'), findsOneWidget);
      expect(find.textContaining('Reviewed Sep 2'), findsNWidgets(2));
    });

    testWidgets('an empty history says so', (tester) async {
      await open(tester, Role.officer, AppRoutes.reviewedIssues);
      expect(find.text("You haven't reviewed any issues yet."), findsOneWidget);
    });

    testWidgets('a reviewed advisory opens read-only', (tester) async {
      reviewed = [issueJson(status: 'Resolved', advisoryStatus: 'Approved')];
      advisory = officerAdvisoryJson(status: 'Approved');
      await open(tester, Role.officer, AppRoutes.reviewedIssues);
      await tester.tap(find.text('Yellow leaves'));
      await tester.pumpAndSettle();
      expect(key('review-approve'), findsNothing);
    });
  });

  group('All Issues', () {
    testWidgets('an admin sees every issue with where it stands', (tester) async {
      everything = [
        issueJson(),
        {...issueJson(id: 9, status: 'Resolved', advisoryStatus: 'Approved'), 'title': 'Done one'},
      ];
      await open(tester, Role.admin, AppRoutes.allIssues);
      expect(find.text('Yellow leaves'), findsOneWidget);
      expect(find.text('Done one'), findsOneWidget);
      expect(find.text('Awaiting review'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
    });

    testWidgets('an admin can still decide an issue that is waiting', (tester) async {
      everything = [issueJson()];
      await open(tester, Role.admin, AppRoutes.allIssues);
      await tester.tap(find.text('Yellow leaves'));
      await tester.pumpAndSettle();
      await scrollTo(tester, key('review-approve'));
      expect(key('review-approve'), findsOneWidget);
    });

    testWidgets('an officer cannot open it and lands on their own home', (tester) async {
      final app = await open(tester, Role.officer, AppRoutes.allIssues);
      final path = app.container.read(routerProvider).routerDelegate.currentConfiguration.uri.path;
      expect(path, AppRoutes.officerDashboard);
    });
  });
}
