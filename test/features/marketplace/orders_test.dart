import 'package:agrilink_mobile/app/router/app_routes.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:agrilink_mobile/features/marketplace/application/contact_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';
import 'marketplace_fixtures.dart';
import 'marketplace_test_helpers.dart';

/// Records what would have been opened instead of opening the phone or email app.
class _FakeLauncher extends ContactLauncher {
  final List<String> opened = [];
  bool works = true;

  @override
  Future<bool> call(String phone) async {
    opened.add('tel:$phone');
    return works;
  }

  @override
  Future<bool> email(String address) async {
    opened.add('mailto:$address');
    return works;
  }
}

void main() {
  FakeApi ordersApi(Role role, {String status = 'Confirmed', String? buyerPhone = '0771234567'}) =>
      marketplaceFakeApi(role)
        ..on(
          'GET',
          '/api/orders/mine',
          (_) => FakeResponse(200, [
            orderJson(id: 40, status: 'Completed', orderDate: '2026-09-01T09:00:00Z'),
            orderJson(status: status),
          ]),
        )
        ..on(
          'GET',
          '/api/orders/41',
          (_) => FakeResponse(200, orderJson(status: status, buyerPhone: buyerPhone)),
        );

  Future<_FakeLauncher> openOrder(
    WidgetTester tester, {
    required Role role,
    required FakeApi api,
  }) async {
    final launcher = _FakeLauncher();
    final app = await pumpAgriLink(
      tester,
      api: api,
      session: Session(token: fakeJwt(), role: role),
      overrides: [contactLauncherProvider.overrideWithValue(launcher)],
    );
    await pushPath(app, '/orders/41');
    return launcher;
  }

  testWidgets('lists orders newest first with the other party and can filter them', (tester) async {
    await pumpMarketplace(
      tester,
      role: Role.buyer,
      api: ordersApi(Role.buyer),
      path: AppRoutes.orders,
    );

    final newest = tester.getTopLeft(find.byKey(const Key('order-41')));
    final older = tester.getTopLeft(find.byKey(const Key('order-40')));
    expect(newest.dy, lessThan(older.dy));
    // A buyer sees the farmer they bought from.
    expect(find.text('Sunil Perera'), findsNWidgets(2));
    expect(find.text('Rs 6,000'), findsNWidgets(2));

    await tester.tapVisible(find.text('Completed (1)'));
    expect(find.byKey(const Key('order-41')), findsNothing);
    expect(find.byKey(const Key('order-40')), findsOneWidget);
  });

  testWidgets("a farmer sees the buyer's contact card and can call or email them", (tester) async {
    final launcher = await openOrder(tester, role: Role.farmer, api: ordersApi(Role.farmer));

    expect(find.text('Order #41'), findsOneWidget);
    expect(find.text('Nimal Silva'), findsOneWidget);
    expect(find.textContaining('Silva Traders'), findsOneWidget);

    await tester.tapVisible(find.byKey(const Key('contact-phone')));
    await tester.tapVisible(find.byKey(const Key('contact-email')));

    expect(launcher.opened, ['tel:0771234567', 'mailto:buyer@example.test']);
  });

  testWidgets('says when there is no phone number, and when no app can open a link', (
    tester,
  ) async {
    final launcher = await openOrder(
      tester,
      role: Role.farmer,
      api: ordersApi(Role.farmer, buyerPhone: null),
    );
    launcher.works = false;

    expect(find.byKey(const Key('contact-no-phone')), findsOneWidget);
    await tester.tapVisible(find.byKey(const Key('contact-email')));

    expect(find.text('No app on this phone can open this.'), findsOneWidget);
  });

  testWidgets('completing a confirmed order is confirmed first, then refreshed', (tester) async {
    final api = ordersApi(Role.buyer);
    api.on('POST', '/api/orders/41/complete', (_) {
      // From now on the server reports it completed.
      api.on('GET', '/api/orders/41', (_) => FakeResponse(200, orderJson(status: 'Completed')));
      return FakeResponse(200, orderJson(status: 'Completed'));
    });
    await openOrder(tester, role: Role.buyer, api: api);

    // A buyer sees the farmer's details.
    expect(find.text('Sunil Perera'), findsOneWidget);
    await tester.tapVisible(find.byKey(const Key('complete-order')));
    expect(find.textContaining('once the harvest has been delivered'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Mark as completed').last);
    await tester.pumpAndSettle();

    expect(api.lastTo('POST', '/api/orders/41/complete'), isNotNull);
    expect(find.text('Order marked as completed.'), findsOneWidget);
    // Only a confirmed order has the buttons.
    expect(find.byKey(const Key('complete-order')), findsNothing);
    expect(find.byKey(const Key('cancel-order')), findsNothing);
  });

  testWidgets('cancelling can be backed out of with Keep order', (tester) async {
    final api = ordersApi(Role.farmer);
    await openOrder(tester, role: Role.farmer, api: api);

    await tester.tapVisible(find.byKey(const Key('cancel-order')));
    expect(find.text('Cancel this order? The quantity goes back on the listing.'), findsOneWidget);
    await tester.tap(find.text('Keep order'));
    await tester.pumpAndSettle();

    expect(api.lastTo('POST', '/api/orders/41/cancel'), isNull);
  });

  testWidgets("shows the server's reason when the order has already changed", (tester) async {
    final api = ordersApi(Role.farmer)
      ..on(
        'POST',
        '/api/orders/41/cancel',
        (_) => const FakeResponse(400, {
          'message': 'Only confirmed orders can be completed or cancelled.',
        }),
      );
    await openOrder(tester, role: Role.farmer, api: api);

    await tester.tapVisible(find.byKey(const Key('cancel-order')));
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel order'));
    await tester.pumpAndSettle();

    expect(find.text('Only confirmed orders can be completed or cancelled.'), findsOneWidget);
  });

  testWidgets('a completed or cancelled order has no actions', (tester) async {
    await openOrder(
      tester,
      role: Role.buyer,
      api: ordersApi(Role.buyer, status: 'Cancelled'),
    );

    expect(find.byKey(const Key('complete-order')), findsNothing);
    expect(find.byKey(const Key('cancel-order')), findsNothing);
    expect(find.textContaining('Completed '), findsOneWidget);
  });
}
