import 'package:agrilink_mobile/app/router/app_router.dart';
import 'package:agrilink_mobile/app/router/app_routes.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:agrilink_mobile/features/admin/application/user_filter.dart';
import 'package:agrilink_mobile/features/admin/data/admin_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';
import 'admin_fixtures.dart';

AdminUser user(Map<String, Object?> json) => AdminUser.fromJson(json);

void main() {
  group('filterUsers', () {
    final users = [
      user(adminUserJson(id: 1)),
      user(adminUserJson(name: 'Nimali Silva', role: 'Buyer', department: null)),
      user(
        adminUserJson(
          id: 3,
          name: 'Sunil Fernando',
          role: 'Farmer',
          isActive: false,
          department: null,
        ),
      ),
      user(
        adminUserJson(id: 4, name: 'Admin One', role: 'Admin', district: null, department: null),
      ),
    ];

    List<int> ids(List<AdminUser> found) => [for (final u in found) u.userId];

    test('with nothing chosen every user is shown', () {
      expect(ids(filterUsers(users)), [1, 2, 3, 4]);
    });

    test('search matches part of the name, ignoring case and surrounding spaces', () {
      expect(ids(filterUsers(users, query: '  NIMA ')), [2]);
    });

    test('search matches the email', () {
      expect(ids(filterUsers(users, query: 'user3@')), [3]);
    });

    test('search matches the username', () {
      expect(ids(filterUsers(users, query: 'user4')), [4]);
    });

    test('a search with no match finds nobody', () {
      expect(filterUsers(users, query: 'zzz'), isEmpty);
    });

    test('the role filter keeps only that role', () {
      expect(ids(filterUsers(users, role: Role.buyer)), [2]);
      expect(ids(filterUsers(users, role: Role.admin)), [4]);
    });

    test('the status filter separates active from inactive accounts', () {
      expect(ids(filterUsers(users, status: UserStatusFilter.active)), [1, 2, 4]);
      expect(ids(filterUsers(users, status: UserStatusFilter.inactive)), [3]);
    });

    test('search, role and status narrow together', () {
      expect(
        ids(
          filterUsers(users, query: 'sunil', role: Role.farmer, status: UserStatusFilter.inactive),
        ),
        [3],
      );
      expect(
        filterUsers(users, query: 'sunil', role: Role.farmer, status: UserStatusFilter.active),
        isEmpty,
      );
    });
  });

  group('the users screen', () {
    late FakeApi api;

    setUp(() {
      api = FakeApi()
        ..on(
          'GET',
          '/api/admin/users',
          (_) => FakeResponse(200, [
            adminUserJson(id: 1),
            adminUserJson(name: 'Nimali Silva', role: 'Buyer', department: null),
            adminUserJson(
              id: 3,
              name: 'Sunil Fernando',
              role: 'Farmer',
              isActive: false,
              department: null,
            ),
          ]),
        );
    });

    Future<TestApp> open(WidgetTester tester, {String language = 'en', Size? screen}) async {
      api.on('GET', '/api/users/me', (_) => FakeResponse(200, profileJson(Role.admin)));
      final app = await pumpAgriLink(
        tester,
        api: api,
        session: Session(token: fakeJwt(), role: Role.admin),
        language: language,
        screen: screen ?? const Size(390, 844),
      );
      app.container.read(routerProvider).go(AppRoutes.adminUsers);
      await tester.pumpAndSettle();
      return app;
    }

    testWidgets('each user is a card with role, place and active state', (tester) async {
      await open(tester);
      expect(find.text('Showing 3 of 3 users'), findsOneWidget);
      expect(find.text('Kamal Perera'), findsOneWidget);
      expect(find.text('user1@example.lk'), findsOneWidget);
      expect(find.text('@user1'), findsOneWidget);
      expect(find.text('Kandy · Agriculture'), findsOneWidget);
      expect(find.text('Inactive'), findsWidgets);
    });

    testWidgets('typing in the search box narrows the list', (tester) async {
      await open(tester);
      await tester.enterText(find.byKey(const Key('user-search')), 'nimali');
      await tester.pumpAndSettle();
      expect(find.text('Nimali Silva'), findsOneWidget);
      expect(find.text('Kamal Perera'), findsNothing);
      expect(find.text('Showing 1 of 3 users'), findsOneWidget);
    });

    testWidgets('the role and status filters narrow the list', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('role-Buyer')));
      await tester.pumpAndSettle();
      expect(find.text('Nimali Silva'), findsOneWidget);
      expect(find.text('Kamal Perera'), findsNothing);

      await tester.tap(find.byKey(const Key('status-inactive')));
      await tester.pumpAndSettle();
      // No buyer is inactive.
      expect(find.text('No users match your search or filters.'), findsOneWidget);
    });

    testWidgets('clearing the filters brings everyone back', (tester) async {
      await open(tester);
      await tester.enterText(find.byKey(const Key('user-search')), 'nobody');
      await tester.pumpAndSettle();
      expect(find.text('No users match your search or filters.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('clear-filters')));
      await tester.pumpAndSettle();
      expect(find.text('Showing 3 of 3 users'), findsOneWidget);
    });

    testWidgets('an empty list says so', (tester) async {
      api.on('GET', '/api/admin/users', (_) => const FakeResponse(200, <Object?>[]));
      await open(tester);
      expect(find.text('No users found.'), findsOneWidget);
    });

    testWidgets('a failed load shows an error with Try again', (tester) async {
      api.offline('GET', '/api/admin/users');
      await open(tester);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('the cards and filters fit a narrow screen in Sinhala', (tester) async {
      await open(tester, language: 'si', screen: const Size(320, 640));
      expect(tester.takeException(), isNull);
      expect(find.text('Kamal Perera'), findsOneWidget);
    });
  });
}
