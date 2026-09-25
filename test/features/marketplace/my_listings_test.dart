import 'package:agrilink_mobile/app/router/app_routes.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/features/marketplace/data/harvest_listing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';
import 'marketplace_fixtures.dart';
import 'marketplace_test_helpers.dart';

void main() {
  FakeApi farmerApi({List<Object> crops = const []}) => marketplaceFakeApi(Role.farmer)
    ..on(
      'GET',
      '/api/harvests/mine',
      (_) => FakeResponse(200, [
        listingJson(id: 1),
        listingJson(id: 2, status: 'Sold', availableQuantity: 0),
        listingJson(id: 3, status: 'Cancelled'),
      ]),
    )
    ..on('GET', '/api/crops/mine', (_) => FakeResponse(200, crops));

  testWidgets('shows every status and narrows the list by status', (tester) async {
    await pumpMarketplace(tester, role: Role.farmer, api: farmerApi(), path: AppRoutes.myListings);

    expect(find.byKey(const Key('harvest-1')), findsOneWidget);
    expect(find.byKey(const Key('harvest-2')), findsOneWidget);
    expect(find.text('All (3)'), findsOneWidget);
    expect(find.text('0 of 500 kg available'), findsOneWidget);

    // The chips scroll sideways; Sold is off to the right on a phone.
    await tester.tapVisible(find.text('Sold (1)'));

    expect(find.byKey(const Key('harvest-1')), findsNothing);
    expect(find.byKey(const Key('harvest-2')), findsOneWidget);
  });

  testWidgets('publishes a new listing for one of my crops', (tester) async {
    final api = farmerApi(
      crops: [
        cropJson(),
        cropJson(id: 4, cropType: 'Tomato'),
      ],
    )..on('POST', '/api/harvests', (_) => FakeResponse(201, listingJson(id: 9)));
    await pumpMarketplace(tester, role: Role.farmer, api: api, path: AppRoutes.myListings);

    await tester.tap(find.byKey(const Key('new-listing')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('listing-crop')));
    await tester.pumpAndSettle();
    expect(find.text('North Field · Green Acres'), findsWidgets);
    await tester.tap(find.text('Paddy · Samba').last);
    await tester.pumpAndSettle();

    // The location starts as the farm's district, and the expected yield is shown.
    expect(find.text('Kurunegala'), findsOneWidget);
    expect(find.text('Expected yield: 600 kg'), findsOneWidget);

    await tester.fill(find.byKey(const Key('listing-quantity')), '250');
    await tester.fill(find.byKey(const Key('listing-price')), '110');
    expect(find.text('Rs 27,500'), findsOneWidget);

    await tester.tapVisible(find.byKey(const Key('listing-harvest-date')));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tapVisible(find.byKey(const Key('listing-publish')));

    expect(api.lastTo('POST', '/api/harvests')!.json, {
      'cropId': 3,
      'quantity': 250.0,
      'harvestDate': apiDateOnly(DateTime.now()),
      'pricePerUnit': 110.0,
      'location': 'Kurunegala',
    });
    expect(find.text('Listing published.'), findsOneWidget);
  });

  testWidgets('checks every field before publishing', (tester) async {
    final api = farmerApi(crops: [cropJson()]);
    await pumpMarketplace(tester, role: Role.farmer, api: api, path: AppRoutes.myListings);

    await tester.tap(find.byKey(const Key('new-listing')));
    await tester.pumpAndSettle();
    await tester.tapVisible(find.byKey(const Key('listing-publish')));

    expect(find.text('Choose which crop this is for.'), findsOneWidget);
    expect(find.text('Quantity must be greater than 0'), findsOneWidget);
    expect(find.text('Price must be greater than 0'), findsOneWidget);
    expect(find.text('Harvest date is required'), findsOneWidget);
    expect(api.lastTo('POST', '/api/harvests'), isNull);
  });

  testWidgets('with no crops yet, points the farmer to their farms', (tester) async {
    await pumpMarketplace(tester, role: Role.farmer, api: farmerApi(), path: AppRoutes.myListings);

    await tester.tap(find.byKey(const Key('new-listing')));
    await tester.pumpAndSettle();

    expect(find.text('You have no crops to list yet.'), findsOneWidget);
    expect(find.text('Go to My Farms'), findsOneWidget);
  });

  testWidgets('quick edit opens the editor for that listing', (tester) async {
    await pumpMarketplace(tester, role: Role.farmer, api: farmerApi(), path: AppRoutes.myListings);

    await tester.tapVisible(find.byKey(const Key('quick-edit-3')));

    expect(find.text('Edit Listing'), findsOneWidget);
    expect(find.byKey(const Key('edit-save')), findsOneWidget);
  });

  testWidgets('with no listings, explains how to start', (tester) async {
    final api = marketplaceFakeApi(Role.farmer)
      ..on('GET', '/api/harvests/mine', (_) => const FakeResponse(200, []));
    await pumpMarketplace(tester, role: Role.farmer, api: api, path: AppRoutes.myListings);

    expect(find.text("You haven't listed any harvests yet."), findsOneWidget);
  });
}
