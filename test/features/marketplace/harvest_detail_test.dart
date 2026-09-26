import 'package:agrilink_mobile/core/session/role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';
import 'marketplace_fixtures.dart';
import 'marketplace_test_helpers.dart';

/// The test profile's farmerProfileId (see `profileJson`).
const _myFarmerProfileId = 7;

void main() {
  FakeApi apiFor(Role role, {int farmerProfileId = 11, String status = 'Active'}) =>
      marketplaceFakeApi(role)..on(
        'GET',
        '/api/harvests/7',
        (_) => FakeResponse(
          200,
          listingJson(farmerProfileId: farmerProfileId, status: status, availableQuantity: 40),
        ),
      );

  group('a buyer', () {
    testWidgets('sees the listing and can ask to buy it', (tester) async {
      final api = apiFor(Role.buyer)
        ..on('POST', '/api/purchase-requests', (_) => FakeResponse(201, requestJson()));
      await pumpMarketplace(tester, role: Role.buyer, api: api, path: '/marketplace/7');

      expect(find.text('Samba'), findsOneWidget);
      expect(find.text('Rs 120'), findsOneWidget);
      expect(find.text('40 kg'), findsOneWidget);
      expect(find.byKey(const Key('edit-listing')), findsNothing);

      await tester.tap(find.byKey(const Key('request-to-buy')));
      await tester.pumpAndSettle();
      await tester.fill(find.byKey(const Key('request-quantity')), '25');
      await tester.fill(find.byKey(const Key('request-message')), 'Can you deliver?');
      await tester.tapVisible(find.byKey(const Key('request-send')));

      expect(api.lastTo('POST', '/api/purchase-requests')!.json, {
        'harvestId': 7,
        'requestedQuantity': 25.0,
        'message': 'Can you deliver?',
      });
      expect(find.byKey(const Key('request-sent')), findsOneWidget);
      expect(find.byKey(const Key('view-my-requests')), findsOneWidget);
    });

    testWidgets('cannot ask for nothing or for more than is available', (tester) async {
      final api = apiFor(Role.buyer);
      await pumpMarketplace(tester, role: Role.buyer, api: api, path: '/marketplace/7');
      await tester.tap(find.byKey(const Key('request-to-buy')));
      await tester.pumpAndSettle();

      await tester.tapVisible(find.byKey(const Key('request-send')));
      expect(find.text('Quantity must be greater than 0'), findsOneWidget);

      await tester.fill(find.byKey(const Key('request-quantity')), '41');
      await tester.tapVisible(find.byKey(const Key('request-send')));
      expect(find.text('Only 40 available'), findsOneWidget);

      expect(api.lastTo('POST', '/api/purchase-requests'), isNull);
    });

    testWidgets("sees the server's reason when it refuses", (tester) async {
      final api = apiFor(Role.buyer)
        ..on(
          'POST',
          '/api/purchase-requests',
          (_) => const FakeResponse(400, {'message': 'This harvest listing is not active.'}),
        );
      await pumpMarketplace(tester, role: Role.buyer, api: api, path: '/marketplace/7');
      await tester.tap(find.byKey(const Key('request-to-buy')));
      await tester.pumpAndSettle();
      await tester.fill(find.byKey(const Key('request-quantity')), '5');
      await tester.tapVisible(find.byKey(const Key('request-send')));

      expect(find.text('This harvest listing is not active.'), findsOneWidget);
      expect(find.byKey(const Key('request-sent')), findsNothing);
    });

    testWidgets('cannot ask to buy a listing that is sold', (tester) async {
      await pumpMarketplace(
        tester,
        role: Role.buyer,
        api: apiFor(Role.buyer, status: 'Sold'),
        path: '/marketplace/7',
      );

      expect(find.byKey(const Key('request-to-buy')), findsNothing);
      expect(find.text("This listing isn't for sale any more."), findsOneWidget);
    });
  });

  group('the farmer who listed it', () {
    testWidgets('can cancel it, after confirming', (tester) async {
      final api = apiFor(Role.farmer, farmerProfileId: _myFarmerProfileId)
        ..on('PUT', '/api/harvests/7', (_) => FakeResponse(200, listingJson(status: 'Cancelled')));
      await pumpMarketplace(tester, role: Role.farmer, api: api, path: '/marketplace/7');

      expect(find.byKey(const Key('request-to-buy')), findsNothing);
      await tester.tap(find.byKey(const Key('edit-listing')));
      await tester.pumpAndSettle();
      expect(find.textContaining('audit log'), findsNothing);

      await tester.tap(find.byKey(const Key('edit-status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelled').last);
      await tester.pumpAndSettle();
      await tester.fill(find.byKey(const Key('edit-price')), '135');
      await tester.tapVisible(find.byKey(const Key('edit-save')));

      expect(find.text('Change this listing to Cancelled?'), findsOneWidget);
      expect(api.lastTo('PUT', '/api/harvests/7'), isNull);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(api.lastTo('PUT', '/api/harvests/7')!.json, {
        'status': 'Cancelled',
        'pricePerUnit': 135.0,
        'location': 'Wariyapola',
        'harvestDate': '2026-09-20',
      });
      expect(find.text('Listing updated.'), findsOneWidget);
    });

    testWidgets("sees why the server won't reopen a listing", (tester) async {
      final api = apiFor(Role.farmer, farmerProfileId: _myFarmerProfileId, status: 'Cancelled')
        ..on(
          'PUT',
          '/api/harvests/7',
          (_) => const FakeResponse(400, {
            'message': 'A listing with no quantity left cannot be reopened.',
          }),
        );
      await pumpMarketplace(tester, role: Role.farmer, api: api, path: '/marketplace/7');
      await tester.tap(find.byKey(const Key('edit-listing')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit-status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Active').last);
      await tester.pumpAndSettle();
      // Reopening needs no confirmation.
      await tester.tapVisible(find.byKey(const Key('edit-save')));

      expect(find.text('A listing with no quantity left cannot be reopened.'), findsOneWidget);
    });
  });

  testWidgets("another farmer can only read someone else's listing", (tester) async {
    await pumpMarketplace(
      tester,
      role: Role.farmer,
      api: apiFor(Role.farmer),
      path: '/marketplace/7',
    );

    expect(find.text('Samba'), findsOneWidget);
    expect(find.byKey(const Key('edit-listing')), findsNothing);
    expect(find.byKey(const Key('request-to-buy')), findsNothing);
  });

  testWidgets('an admin can edit any listing and is told it is audited', (tester) async {
    await pumpMarketplace(
      tester,
      role: Role.admin,
      api: apiFor(Role.admin),
      path: '/marketplace/7',
    );

    await tester.tap(find.byKey(const Key('edit-listing')));
    await tester.pumpAndSettle();

    expect(find.textContaining('audit log'), findsOneWidget);
  });

  testWidgets('a listing that does not exist says so', (tester) async {
    await pumpMarketplace(
      tester,
      role: Role.buyer,
      api: marketplaceFakeApi(Role.buyer),
      path: '/marketplace/99',
    );

    expect(find.text('Listing not found.'), findsOneWidget);
  });
}
