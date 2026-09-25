import 'package:agrilink_mobile/app/router/app_router.dart';
import 'package:agrilink_mobile/app/router/app_routes.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';
import 'marketplace_fixtures.dart';
import 'marketplace_test_helpers.dart';

/// Sinhala and Tamil words are often much longer than English. Every marketplace screen and form
/// is opened in both on a small phone; any overflow fails the test.
void main() {
  FakeApi everything(Role role) => marketplaceFakeApi(role)
    ..on(
      'GET',
      '/api/harvests',
      (_) => FakeResponse(200, [listingJson(), listingJson(id: 8, status: 'Sold')]),
    )
    ..on(
      'GET',
      '/api/harvests/mine',
      (_) => FakeResponse(200, [
        listingJson(farmerProfileId: 7),
        listingJson(id: 8, status: 'Cancelled', farmerProfileId: 7),
      ]),
    )
    ..on('GET', '/api/harvests/7', (_) => FakeResponse(200, listingJson(farmerProfileId: 7)))
    ..on('GET', '/api/crops/mine', (_) => FakeResponse(200, [cropJson()]))
    ..on(
      'GET',
      '/api/purchase-requests/mine',
      (_) => FakeResponse(200, [requestJson(), requestJson(id: 23, status: 'Cancelled')]),
    )
    ..on(
      'GET',
      '/api/purchase-requests/sent',
      (_) => FakeResponse(200, [requestJson(), requestJson(id: 24, status: 'Declined')]),
    )
    ..on('GET', '/api/orders/mine', (_) => FakeResponse(200, [orderJson()]))
    ..on('GET', '/api/orders/41', (_) => FakeResponse(200, orderJson()));

  for (final language in ['si', 'ta']) {
    group('in $language on a small phone', () {
      Future<TestApp> open(WidgetTester tester, Role role, String path) async {
        final app = await pumpAgriLink(
          tester,
          api: everything(role),
          session: Session(token: fakeJwt(), role: role),
          language: language,
          screen: const Size(320, 640),
        );
        app.container.read(routerProvider).go(path);
        await tester.pumpAndSettle();
        return app;
      }

      Future<void> tapKey(WidgetTester tester, String key) async {
        await tester.tapVisible(find.byKey(Key(key)));
      }

      testWidgets('the buyer screens and forms', (tester) async {
        await open(tester, Role.buyer, AppRoutes.marketplace);
        expect(find.byKey(const Key('harvest-7')), findsOneWidget);
        await tapKey(tester, 'open-filters');
        await tester.tapAt(const Offset(160, 20)); // close the sheet
        await tester.pumpAndSettle();

        final app = await open(tester, Role.buyer, '/marketplace/7');
        await tapKey(tester, 'request-to-buy');
        expect(find.byKey(const Key('request-send')), findsOneWidget);

        app.container.read(routerProvider).go(AppRoutes.sentRequests);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('request-21')), findsOneWidget);

        await open(tester, Role.buyer, AppRoutes.orders);
        await tapKey(tester, 'order-41');
        // Below the fold on a small phone.
        await tester.reveal(find.byKey(const Key('cancel-order')));
        expect(find.byKey(const Key('contact-card')), findsOneWidget);
      });

      testWidgets('the farmer screens and forms', (tester) async {
        await open(tester, Role.farmer, AppRoutes.myListings);
        await tapKey(tester, 'new-listing');
        await tester.tap(find.byKey(const Key('listing-crop')));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Samba').last);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('listing-publish')), findsOneWidget);

        await open(tester, Role.farmer, '/marketplace/7');
        await tapKey(tester, 'edit-listing');
        expect(find.byKey(const Key('edit-save')), findsOneWidget);

        await open(tester, Role.farmer, AppRoutes.incomingRequests);
        expect(find.byKey(const Key('accept-21')), findsOneWidget);
        await tapKey(tester, 'accept-21');
        expect(find.byType(AlertDialog), findsOneWidget);
      });
    });
  }
}
