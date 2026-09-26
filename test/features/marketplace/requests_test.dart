import 'package:agrilink_mobile/app/router/app_routes.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';
import 'marketplace_fixtures.dart';
import 'marketplace_test_helpers.dart';

void main() {
  group("the farmer's incoming requests", () {
    FakeApi farmerApi() => marketplaceFakeApi(Role.farmer)
      ..on(
        'GET',
        '/api/purchase-requests/mine',
        (_) => FakeResponse(200, [
          requestJson(),
          requestJson(id: 22, status: 'Accepted'),
          requestJson(id: 23, status: 'Cancelled'),
        ]),
      )
      ..on('GET', '/api/orders/mine', (_) => const FakeResponse(200, []));

    testWidgets('groups the requests with pending first, and only pending can be answered', (
      tester,
    ) async {
      await pumpMarketplace(
        tester,
        role: Role.farmer,
        api: farmerApi(),
        path: AppRoutes.incomingRequests,
      );

      expect(find.text('Pending (1)'), findsOneWidget);
      expect(find.text('Accepted (1)'), findsOneWidget);
      expect(find.text('From Nimal Silva · Silva Traders'), findsWidgets);
      expect(find.byKey(const Key('accept-21')), findsOneWidget);
      expect(find.byKey(const Key('accept-22')), findsNothing);
      // An old request the server closed by itself.
      await tester.reveal(find.byKey(const Key('request-23')));
      expect(find.text('Closed – listing unavailable (1)'), findsOneWidget);
    });

    testWidgets('accepting states the quantity and total, then creates the order', (tester) async {
      final api = farmerApi()
        ..on(
          'POST',
          '/api/purchase-requests/21/respond',
          (_) => FakeResponse(200, requestJson(status: 'Accepted')),
        );
      await pumpMarketplace(tester, role: Role.farmer, api: api, path: AppRoutes.incomingRequests);

      await tester.tap(find.byKey(const Key('accept-21')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Sell 50 kg of Paddy to Silva Traders for Rs 6,000. '
          'This creates an order and takes the quantity off your listing.',
        ),
        findsOneWidget,
      );
      final loadsBefore = api.requests.where((r) => r.path == '/api/purchase-requests/mine').length;
      await tester.tap(find.widgetWithText(FilledButton, 'Accept').last);
      await tester.pumpAndSettle();

      expect(api.lastTo('POST', '/api/purchase-requests/21/respond')!.json, {'action': 'accept'});
      expect(find.text('Request accepted — order created.'), findsOneWidget);
      // The list reloads to show the server's new state.
      expect(
        api.requests.where((r) => r.path == '/api/purchase-requests/mine').length,
        greaterThan(loadsBefore),
      );
    });

    testWidgets('backing out of the confirmation sends nothing', (tester) async {
      final api = farmerApi();
      await pumpMarketplace(tester, role: Role.farmer, api: api, path: AppRoutes.incomingRequests);

      await tester.tap(find.byKey(const Key('decline-21')));
      await tester.pumpAndSettle();
      expect(find.text('Decline this request?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(api.lastTo('POST', '/api/purchase-requests/21/respond'), isNull);
    });

    for (final message in [
      'Not enough available quantity to accept this request.',
      'Only pending requests can be responded to.',
      'This listing has been cancelled, so its requests can only be declined.',
    ]) {
      testWidgets('shows the server refusing: $message', (tester) async {
        final api = farmerApi()
          ..on(
            'POST',
            '/api/purchase-requests/21/respond',
            (_) => FakeResponse(400, {'message': message}),
          );
        await pumpMarketplace(
          tester,
          role: Role.farmer,
          api: api,
          path: AppRoutes.incomingRequests,
        );

        await tester.tap(find.byKey(const Key('accept-21')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Accept').last);
        await tester.pumpAndSettle();

        expect(find.text(message), findsOneWidget);
      });
    }

    testWidgets('declining is confirmed and sent', (tester) async {
      final api = farmerApi()
        ..on(
          'POST',
          '/api/purchase-requests/21/respond',
          (_) => FakeResponse(200, requestJson(status: 'Declined')),
        );
      await pumpMarketplace(tester, role: Role.farmer, api: api, path: AppRoutes.incomingRequests);

      await tester.tap(find.byKey(const Key('decline-21')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Decline'));
      await tester.pumpAndSettle();

      expect(api.lastTo('POST', '/api/purchase-requests/21/respond')!.json, {'action': 'decline'});
      expect(find.text('Request declined.'), findsOneWidget);
    });
  });

  group("the buyer's sent requests", () {
    testWidgets('show each status and open the listing', (tester) async {
      final api = marketplaceFakeApi(Role.buyer)
        ..on(
          'GET',
          '/api/purchase-requests/sent',
          (_) => FakeResponse(200, [requestJson(), requestJson(id: 24, status: 'Declined')]),
        )
        ..on('GET', '/api/harvests/7', (_) => FakeResponse(200, listingJson()));
      await pumpMarketplace(tester, role: Role.buyer, api: api, path: AppRoutes.sentRequests);

      expect(find.text('Pending (1)'), findsOneWidget);
      expect(find.text('Declined (1)'), findsOneWidget);
      expect(find.byKey(const Key('accept-21')), findsNothing);
      expect(find.textContaining('From '), findsNothing);

      await tester.tap(find.byKey(const Key('request-21')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('request-to-buy')), findsOneWidget);
    });

    testWidgets('with none yet, points to the marketplace', (tester) async {
      final api = marketplaceFakeApi(Role.buyer)
        ..on('GET', '/api/purchase-requests/sent', (_) => const FakeResponse(200, []));
      await pumpMarketplace(tester, role: Role.buyer, api: api, path: AppRoutes.sentRequests);

      expect(find.text("You haven't requested to buy anything yet."), findsOneWidget);
      expect(find.text('Browse the marketplace'), findsOneWidget);
    });
  });
}
