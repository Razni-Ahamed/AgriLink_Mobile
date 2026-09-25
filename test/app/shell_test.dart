import 'package:agrilink_mobile/app/router/app_router.dart';
import 'package:agrilink_mobile/app/router/app_routes.dart';
import 'package:agrilink_mobile/app/router/route_guard.dart';
import 'package:agrilink_mobile/app/shell/app_shell.dart';
import 'package:agrilink_mobile/app/shell/nav_config.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';
import '../helpers/test_app.dart';

Future<TestApp> signedInAs(
  WidgetTester tester,
  Role role, {
  String language = 'en',
  Size screen = const Size(390, 844),
}) {
  final api = FakeApi()..on('GET', '/api/users/me', (_) => FakeResponse(200, profileJson(role)));
  return pumpAgriLink(
    tester,
    api: api,
    session: Session(token: fakeJwt(), role: role),
    language: language,
    screen: screen,
  );
}

List<String> tabLabels(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(of: find.byType(AppBottomNav), matching: find.byType(Text)))
    .map((text) => text.data!)
    .toList();

String currentPath(TestApp app) =>
    app.container.read(routerProvider).routerDelegate.currentConfiguration.uri.path;

void main() {
  group('each role sees only its own sections', () {
    final expected = {
      Role.farmer: ['Farms', 'My Issues', 'Marketplace', 'Orders', 'More'],
      Role.buyer: ['Marketplace', 'My Requests', 'Orders'],
      Role.officer: ['Dashboard', 'Pending Issues', 'My Reviews', 'Approvals'],
      Role.admin: ['Dashboard', 'Pending Issues', 'Approvals', 'Manage Users', 'More'],
    };
    for (final entry in expected.entries) {
      testWidgets('${entry.key.apiName} tabs', (tester) async {
        final app = await signedInAs(tester, entry.key);
        expect(currentPath(app), homePathFor(entry.key));
        expect(tabLabels(tester), entry.value);
        expect(find.text('Coming soon'), findsOneWidget);
      });
    }
  });

  testWidgets('the farmer finds the other sections under More', (tester) async {
    final app = await signedInAs(tester, Role.farmer);
    await tester.tap(find.byKey(const Key('nav-/more')));
    await tester.pumpAndSettle();
    expect(find.text('My Listings'), findsOneWidget);
    expect(find.text('My Requests'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('My Listings'));
    await tester.pumpAndSettle();
    expect(currentPath(app), AppRoutes.myListings);
    // Still highlighted as "More".
    expect(
      tester.getSemantics(find.byKey(const Key('nav-/more'))),
      containsSemantics(isSelected: true),
    );
  });

  testWidgets('the admin More list has the rest of the admin sections', (tester) async {
    await signedInAs(tester, Role.admin);
    await tester.tap(find.byKey(const Key('nav-/more')));
    await tester.pumpAndSettle();
    for (final label in ['All Issues', 'Marketplace', 'Departments', 'Audit Log']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('switching tabs opens the section', (tester) async {
    final app = await signedInAs(tester, Role.officer);
    await tester.tap(find.byKey(const Key('nav-/registrations/pending')));
    await tester.pumpAndSettle();
    expect(currentPath(app), AppRoutes.approvals);
    expect(find.widgetWithText(AppBar, 'Approvals'), findsOneWidget);
  });

  testWidgets("opening another role's page leads back home", (tester) async {
    final app = await signedInAs(tester, Role.farmer);
    final router = app.container.read(routerProvider);
    for (final path in [AppRoutes.adminUsers, AppRoutes.pendingIssues, AppRoutes.sentRequests]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(currentPath(app), AppRoutes.farms, reason: path);
    }
    router.go(AppRoutes.login);
    await tester.pumpAndSettle();
    expect(currentPath(app), AppRoutes.farms);
  });

  testWidgets('a buyer may open the shared marketplace but not farmer pages', (tester) async {
    final app = await signedInAs(tester, Role.buyer);
    final router = app.container.read(routerProvider);
    router.go(AppRoutes.myListings);
    await tester.pumpAndSettle();
    expect(currentPath(app), AppRoutes.marketplace);
    router.go(AppRoutes.orders);
    await tester.pumpAndSettle();
    expect(currentPath(app), AppRoutes.orders);
  });

  testWidgets('an unknown link shows a not-found page', (tester) async {
    final app = await signedInAs(tester, Role.buyer);
    app.container.read(routerProvider).go('/no/such/page');
    await tester.pumpAndSettle();
    expect(find.text("We couldn't find what you were looking for."), findsOneWidget);
  });

  testWidgets('long Sinhala and Tamil labels fit a small screen with large text', (tester) async {
    for (final language in ['si', 'ta']) {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await signedInAs(tester, Role.admin, language: language, screen: const Size(320, 640));
      expect(tester.takeException(), isNull, reason: language);
      expect(find.byType(AppBottomNav), findsOneWidget);
    }
  });

  group('selectedTabIndex', () {
    final farmer = navigationFor(Role.farmer);
    test('matches a tab, a page inside it, More, or nothing', () {
      expect(selectedTabIndex(farmer, AppRoutes.farms), 0);
      expect(selectedTabIndex(farmer, '/farms/12/fields/3'), 0);
      expect(selectedTabIndex(farmer, AppRoutes.orders), 3);
      expect(selectedTabIndex(farmer, AppRoutes.myListings), 4);
      expect(selectedTabIndex(farmer, AppRoutes.more), 4);
      expect(selectedTabIndex(farmer, AppRoutes.profile), -1);
    });

    test('picks the most specific section', () {
      final admin = navigationFor(Role.admin);
      expect(selectedTabIndex(admin, AppRoutes.adminDashboard), 0);
      expect(selectedTabIndex(admin, AppRoutes.adminUsers), 3);
      expect(selectedTabIndex(admin, '/admin/users/42'), 3);
      expect(selectedTabIndex(admin, AppRoutes.adminAuditLog), 4);
      expect(Destinations.farms.contains('/farmsomething'), isFalse);
    });
  });

  test('redirectForRole sends a role without access home', () {
    expect(redirectForRole(Role.buyer, {Role.farmer}), AppRoutes.marketplace);
    expect(redirectForRole(Role.farmer, {Role.farmer}), isNull);
    expect(redirectForRole(null, {Role.farmer}), isNull);
  });

  test('every role section is listed exactly once in its navigation', () {
    for (final role in Role.values) {
      final paths = navigationFor(role).all.map((d) => d.path).toList();
      expect(paths.toSet().length, paths.length, reason: role.apiName);
      for (final destination in navigationFor(role).all) {
        expect(destination.roles, contains(role), reason: '${role.apiName} ${destination.path}');
      }
    }
  });
}
