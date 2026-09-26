import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import 'farmer_crop.dart';
import 'harvest_listing.dart';
import 'marketplace_enums.dart';
import 'order.dart';
import 'purchase_request.dart';

/// `/api/harvests`, `/api/purchase-requests` and `/api/orders`: the whole trade, from a farmer
/// listing a harvest to the order being completed.
///
/// None of these lists is paged: the API returns them whole, so filtering and sorting happen on
/// the phone.
class MarketplaceApi {
  MarketplaceApi(this._api);

  final ApiClient _api;

  // Harvest listings

  /// Active listings, newest first. Public: it works signed out too.
  Future<List<HarvestListing>> browse({String? cropType, String? district}) => _api.get(
    '/api/harvests',
    query: {'cropType': _blankToNull(cropType), 'district': _blankToNull(district)},
    decode: _listings,
  );

  /// The signed-in farmer's own listings, every status.
  Future<List<HarvestListing>> myListings() => _api.get('/api/harvests/mine', decode: _listings);

  Future<HarvestListing> listing(int id) => _api.get('/api/harvests/$id', decode: _listing);

  Future<HarvestListing> createListing(CreateHarvestListingRequest request) =>
      _api.post('/api/harvests', body: request.toJson(), decode: _listing);

  /// Changes a listing (the farmer's own, or any for an admin). Cancelling it, or selling it
  /// out, closes its pending requests on the server.
  Future<HarvestListing> updateListing(int id, UpdateHarvestListingRequest request) =>
      _api.put('/api/harvests/$id', body: request.toJson(), decode: _listing);

  /// The farmer's crops to choose from when listing a harvest.
  Future<List<FarmerCrop>> myCrops() => _api.get(
    '/api/crops/mine',
    decode: (data) => [for (final item in asJsonList(data)) FarmerCrop.fromJson(item)],
  );

  // Purchase requests

  Future<PurchaseRequest> sendRequest(CreatePurchaseRequestRequest request) =>
      _api.post('/api/purchase-requests', body: request.toJson(), decode: _request);

  /// Requests the signed-in buyer has sent.
  Future<List<PurchaseRequest>> sentRequests() =>
      _api.get('/api/purchase-requests/sent', decode: _requests);

  /// Requests on the signed-in farmer's listings.
  Future<List<PurchaseRequest>> incomingRequests() =>
      _api.get('/api/purchase-requests/mine', decode: _requests);

  /// Accepting creates an order and lowers the listing's available quantity.
  Future<PurchaseRequest> respond(int requestId, RequestAction action) => _api.post(
    '/api/purchase-requests/$requestId/respond',
    body: {'action': action.apiName},
    decode: _request,
  );

  // Orders

  /// The signed-in user's orders, as buyer or as farmer.
  Future<List<Order>> myOrders() => _api.get(
    '/api/orders/mine',
    decode: (data) => [for (final item in asJsonList(data)) Order.fromJson(item)],
  );

  Future<Order> order(int id) => _api.get('/api/orders/$id', decode: _order);

  Future<Order> completeOrder(int id) => _api.post('/api/orders/$id/complete', decode: _order);

  /// Cancelling puts the quantity back on the listing.
  Future<Order> cancelOrder(int id) => _api.post('/api/orders/$id/cancel', decode: _order);

  static HarvestListing _listing(Object? data) => HarvestListing.fromJson(asJson(data));

  static List<HarvestListing> _listings(Object? data) => [
    for (final item in asJsonList(data)) HarvestListing.fromJson(item),
  ];

  static PurchaseRequest _request(Object? data) => PurchaseRequest.fromJson(asJson(data));

  static List<PurchaseRequest> _requests(Object? data) => [
    for (final item in asJsonList(data)) PurchaseRequest.fromJson(item),
  ];

  static Order _order(Object? data) => Order.fromJson(asJson(data));

  static String? _blankToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}

final marketplaceApiProvider = Provider<MarketplaceApi>(
  (ref) => MarketplaceApi(ref.watch(apiClientProvider)),
);
