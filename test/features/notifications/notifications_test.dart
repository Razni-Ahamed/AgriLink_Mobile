import 'package:agrilink_mobile/app/router/app_router.dart';
import 'package:agrilink_mobile/app/router/app_routes.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:agrilink_mobile/core/storage/preferences.dart';
import 'package:agrilink_mobile/shared/permissions/permissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

Map<String, Object?> notificationJson(int id, {bool read = false, String? title}) => {
  'notificationId': id,
  'title': title ?? 'Order #$id confirmed',
  'message': 'Your order #$id has been confirmed by the farmer.',
  'isRead': read,
  'createdAt': '2026-09-25T0${id % 10}:00:00Z',
};

/// A fake notifications API with [total] notifications, the first [unread] of them unread.
class NotificationsBackend {
  NotificationsBackend(this.api, {int total = 3, int unread = 2}) {
    items = [for (var i = 1; i <= total; i++) notificationJson(i, read: i > unread)];
    api
      ..on('GET', '/api/users/me', (_) => FakeResponse(200, profileJson(Role.buyer)))
      ..on(
        'GET',
        '/api/notifications/unread-count',
        (_) => FakeResponse(200, {'count': items.where((n) => n['isRead'] == false).length}),
      )
      ..on('GET', '/api/notifications/mine', (request) {
        final page = int.parse(request.query['page'] ?? '1');
        final pageSize = int.parse(request.query['pageSize'] ?? '20');
        final start = (page - 1) * pageSize;
        final pageItems = items.skip(start).take(pageSize).toList();
        return FakeResponse(200, {
          'items': pageItems,
          'page': page,
          'pageSize': pageSize,
          'totalCount': items.length,
          'totalPages': (items.length / pageSize).ceil(),
        });
      })
      ..on('PUT', '/api/notifications/read-all', (_) {
        items = [
          for (final n in items) {...n, 'isRead': true},
        ];
        return const FakeResponse(204);
      });
    for (var i = 1; i <= 60; i++) {
      api.on('PUT', '/api/notifications/$i/read', (_) {
        items = [
          for (final n in items) n['notificationId'] == i ? {...n, 'isRead': true} : n,
        ];
        return FakeResponse(200, items.firstWhere((n) => n['notificationId'] == i));
      });
    }
  }

  final FakeApi api;
  late List<Map<String, Object?>> items;

  void arrive(int id, {String? title}) => items = [notificationJson(id, title: title), ...items];
}

void main() {
  Future<TestApp> start(
    WidgetTester tester,
    NotificationsBackend backend, {
    FakePermissions? permissions,
    Map<String, Object> preferences = const {},
  }) => pumpAgriLink(
    tester,
    api: backend.api,
    session: Session(token: fakeJwt(), role: Role.buyer),
    permissions: permissions,
    preferences: preferences,
  );

  Finder badge(String count) =>
      find.descendant(of: find.byKey(const Key('notification-bell')), matching: find.text(count));

  testWidgets('the bell shows the unread count', (tester) async {
    await start(tester, NotificationsBackend(FakeApi()));
    expect(badge('2'), findsOneWidget);
    expect(find.byTooltip('Notifications, 2 unread'), findsOneWidget);
  });

  testWidgets('the list marks one as read on tap, and all at once', (tester) async {
    final backend = NotificationsBackend(FakeApi());
    final app = await start(tester, backend);
    await tester.tap(find.byKey(const Key('notification-bell')));
    await tester.pumpAndSettle();
    expect(find.text('Order #1 confirmed'), findsOneWidget);
    expect(find.text('Order #3 confirmed'), findsOneWidget);

    await tester.tap(find.text('Order #1 confirmed'));
    await tester.pumpAndSettle();
    expect(app.api.lastTo('PUT', '/api/notifications/1/read'), isNotNull);
    expect(badge('1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mark-all-read')));
    await tester.pumpAndSettle();
    expect(app.api.lastTo('PUT', '/api/notifications/read-all'), isNotNull);
    expect(badge('1'), findsNothing);
    expect(find.byKey(const Key('mark-all-read')), findsNothing);
  });

  testWidgets('loads more notifications while scrolling', (tester) async {
    final backend = NotificationsBackend(FakeApi(), total: 45, unread: 0);
    await start(tester, backend);
    await tester.tap(find.byKey(const Key('notification-bell')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Order #45 confirmed'), 400);
    expect(find.text('Order #45 confirmed'), findsOneWidget);
    final pages = backend.api.requests
        .where((r) => r.path == '/api/notifications/mine')
        .map((r) => r.query['page']);
    expect(pages, containsAll(['1', '2', '3']));
  });

  testWidgets('shows an empty state', (tester) async {
    await start(tester, NotificationsBackend(FakeApi(), total: 0, unread: 0));
    await tester.tap(find.byKey(const Key('notification-bell')));
    await tester.pumpAndSettle();
    expect(find.text("You don't have any notifications yet."), findsOneWidget);
  });

  testWidgets('a new notification while the app is open pops up, the first count does not', (
    tester,
  ) async {
    final backend = NotificationsBackend(FakeApi(), unread: 1);
    final app = await start(tester, backend);
    expect(app.presenter.announced, isEmpty);

    backend.arrive(50, title: 'New purchase request');
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();

    expect(badge('2'), findsOneWidget);
    expect(app.presenter.announced.single.title, 'New purchase request');

    backend
      ..arrive(51)
      ..arrive(52);
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    expect(app.presenter.announced.last.title, 'You have 2 new notifications');
  });

  testWidgets('tapping a pop-up opens the notifications list', (tester) async {
    final app = await start(tester, NotificationsBackend(FakeApi()));
    app.presenter.openCallback!();
    await tester.pumpAndSettle();
    final path = app.container.read(routerProvider).routerDelegate.currentConfiguration.uri.path;
    expect(path, AppRoutes.notifications);
  });

  testWidgets('signing out stops the count', (tester) async {
    final backend = NotificationsBackend(FakeApi());
    await start(tester, backend);
    int countRequests() =>
        backend.api.requests.where((r) => r.path == '/api/notifications/unread-count').length;
    final before = countRequests();
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    expect(countRequests(), greaterThan(before), reason: 'polls while signed in');

    await tester.tap(find.byKey(const Key('avatar-button')));
    await tester.pumpAndSettle();
    await tester.tapVisible(find.byKey(const Key('sign-out')));
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();

    final afterSignOut = countRequests();
    await tester.pump(const Duration(minutes: 3));
    expect(countRequests(), afterSignOut, reason: 'stops after signing out');
  });

  group('notification permission', () {
    testWidgets('is asked once, a moment after reaching home, with an explanation first', (
      tester,
    ) async {
      final permissions = FakePermissions(PermissionResult.denied);
      final app = await start(
        tester,
        NotificationsBackend(FakeApi()),
        permissions: permissions,
        preferences: {PrefKeys.notificationPermissionAsked: false},
      );
      expect(find.text('Turn on notifications'), findsNothing);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Turn on notifications'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(permissions.requested, [AppPermission.notifications]);
      final preferences = app.container.read(sharedPreferencesProvider);
      expect(preferences.getBool(PrefKeys.notificationPermissionAsked), isTrue);
    });

    testWidgets('is not asked again after "Not now"', (tester) async {
      final permissions = FakePermissions(PermissionResult.denied);
      await start(
        tester,
        NotificationsBackend(FakeApi()),
        permissions: permissions,
        preferences: {PrefKeys.notificationPermissionAsked: true},
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Turn on notifications'), findsNothing);
      expect(permissions.requested, isEmpty);
    });

    testWidgets('the list offers to turn pop-ups on while they are off', (tester) async {
      final permissions = FakePermissions(PermissionResult.denied);
      await start(tester, NotificationsBackend(FakeApi()), permissions: permissions);
      await tester.tap(find.byKey(const Key('notification-bell')));
      await tester.pumpAndSettle();

      permissions.result = PermissionResult.granted;
      await tester.tap(find.byKey(const Key('turn-on-notifications')));
      await tester.pumpAndSettle();
      expect(permissions.requested, [AppPermission.notifications]);
      expect(find.byKey(const Key('turn-on-notifications')), findsNothing);
    });
  });
}
