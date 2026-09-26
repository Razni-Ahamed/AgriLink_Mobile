import 'package:agrilink_mobile/core/api/api_exception.dart';
import 'package:agrilink_mobile/features/marketplace/data/harvest_listing.dart';
import 'package:agrilink_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:agrilink_mobile/features/marketplace/data/marketplace_enums.dart';
import 'package:agrilink_mobile/features/marketplace/data/purchase_request.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import 'marketplace_fixtures.dart';

void main() {
  late FakeApi fake;
  late MarketplaceApi api;

  setUp(() {
    fake = FakeApi();
    api = MarketplaceApi(fakeApiClient(fake));
  });

  test('browse sends only the filters that are set', () async {
    fake.on('GET', '/api/harvests', (_) => FakeResponse(200, [listingJson()]));

    final all = await api.browse();
    expect(all.single.id, 7);
    expect(fake.requests.last.query, isEmpty);

    await api.browse(cropType: 'Paddy', district: ' ');
    expect(fake.requests.last.query, {'cropType': 'Paddy'});
  });

  test('reads the farmer lists and the crops to choose from', () async {
    fake
      ..on('GET', '/api/harvests/mine', (_) => FakeResponse(200, [listingJson(status: 'Sold')]))
      ..on('GET', '/api/crops/mine', (_) => FakeResponse(200, [cropJson()]))
      ..on('GET', '/api/purchase-requests/mine', (_) => FakeResponse(200, [requestJson()]));

    expect((await api.myListings()).single.status, HarvestStatus.sold);
    final crop = (await api.myCrops()).single;
    expect(crop.fieldName, 'North Field');
    expect(crop.farmName, 'Green Acres');
    expect((await api.incomingRequests()).single.id, 21);
  });

  test('creating and updating a listing send the right bodies', () async {
    fake
      ..on('POST', '/api/harvests', (_) => FakeResponse(201, listingJson()))
      ..on('PUT', '/api/harvests/7', (_) => FakeResponse(200, listingJson(status: 'Cancelled')));

    await api.createListing(
      CreateHarvestListingRequest(
        cropId: 3,
        quantity: 500,
        harvestDate: DateTime(2026, 9, 20),
        pricePerUnit: 120,
        location: 'Wariyapola',
      ),
    );
    expect(fake.lastTo('POST', '/api/harvests')!.json['harvestDate'], '2026-09-20');

    final updated = await api.updateListing(
      7,
      const UpdateHarvestListingRequest(status: HarvestStatus.cancelled),
    );
    expect(updated.status, HarvestStatus.cancelled);
    expect(fake.lastTo('PUT', '/api/harvests/7')!.json, {'status': 'Cancelled'});
  });

  test('responding sends the action word the API expects', () async {
    fake.on(
      'POST',
      '/api/purchase-requests/21/respond',
      (_) => FakeResponse(200, requestJson(status: 'Accepted')),
    );

    final request = await api.respond(21, RequestAction.accept);
    expect(request.status, PurchaseRequestStatus.accepted);
    expect(fake.lastTo('POST', '/api/purchase-requests/21/respond')!.json, {'action': 'accept'});
  });

  test("a rule the server refuses comes back with the server's message", () async {
    fake.on(
      'POST',
      '/api/purchase-requests',
      (_) => const FakeResponse(400, {'message': 'Requested quantity exceeds available quantity.'}),
    );

    await expectLater(
      api.sendRequest(const CreatePurchaseRequestRequest(harvestId: 7, requestedQuantity: 999)),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.badRequest)
            .having(
              (e) => e.serverMessage,
              'serverMessage',
              'Requested quantity exceeds available quantity.',
            ),
      ),
    );
  });

  test('orders: list, complete and cancel', () async {
    fake
      ..on('GET', '/api/orders/mine', (_) => FakeResponse(200, [orderJson()]))
      ..on(
        'POST',
        '/api/orders/41/complete',
        (_) => FakeResponse(200, orderJson(status: 'Completed')),
      )
      ..on(
        'POST',
        '/api/orders/41/cancel',
        (_) => FakeResponse(200, orderJson(status: 'Cancelled')),
      );

    expect((await api.myOrders()).single.id, 41);
    expect((await api.completeOrder(41)).status, OrderStatus.completed);
    expect((await api.cancelOrder(41)).status, OrderStatus.cancelled);
  });
}
