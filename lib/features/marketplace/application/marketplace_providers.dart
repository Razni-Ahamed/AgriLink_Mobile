import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../data/farmer_crop.dart';
import '../data/harvest_listing.dart';
import '../data/marketplace_api.dart';
import '../data/order.dart';
import '../data/purchase_request.dart';

/// The crop and district filters sent to the server when browsing.
typedef BrowseFilters = ({String? cropType, String? district});

/// Active listings for the browse screen, filtered by crop and district on the server.
final browseListingsProvider = FutureProvider.autoDispose
    .family<List<HarvestListing>, BrowseFilters>((ref, filters) {
      ref.watch(sessionTokenProvider);
      return ref
          .watch(marketplaceApiProvider)
          .browse(cropType: filters.cropType, district: filters.district);
    });

/// One listing by id.
final listingProvider = FutureProvider.autoDispose.family<HarvestListing, int>((ref, id) {
  ref.watch(sessionTokenProvider);
  return ref.watch(marketplaceApiProvider).listing(id);
});

/// The signed-in farmer's own listings, every status.
final myListingsProvider = FutureProvider.autoDispose<List<HarvestListing>>((ref) {
  ref.watch(sessionTokenProvider);
  return ref.watch(marketplaceApiProvider).myListings();
});

/// The farmer's crops, for the "list a harvest" form.
final myCropsProvider = FutureProvider.autoDispose<List<FarmerCrop>>((ref) {
  ref.watch(sessionTokenProvider);
  return ref.watch(marketplaceApiProvider).myCrops();
});

/// Requests on the signed-in farmer's listings.
final incomingRequestsProvider = FutureProvider.autoDispose<List<PurchaseRequest>>((ref) {
  ref.watch(sessionTokenProvider);
  return ref.watch(marketplaceApiProvider).incomingRequests();
});

/// Requests the signed-in buyer has sent.
final sentRequestsProvider = FutureProvider.autoDispose<List<PurchaseRequest>>((ref) {
  ref.watch(sessionTokenProvider);
  return ref.watch(marketplaceApiProvider).sentRequests();
});

/// The signed-in user's orders, newest first.
final myOrdersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  ref.watch(sessionTokenProvider);
  final orders = await ref.watch(marketplaceApiProvider).myOrders();
  return orders..sort((a, b) => b.orderDate.compareTo(a.orderDate));
});

/// One order by id.
final orderProvider = FutureProvider.autoDispose.family<Order, int>((ref, id) {
  ref.watch(sessionTokenProvider);
  return ref.watch(marketplaceApiProvider).order(id);
});

/// After a trade action the server changes several things at once (a request's status, the
/// listing's available quantity, a new or changed order), so everything that shows them reloads.
void refreshTrade(WidgetRef ref) {
  ref
    ..invalidate(browseListingsProvider)
    ..invalidate(listingProvider)
    ..invalidate(myListingsProvider)
    ..invalidate(incomingRequestsProvider)
    ..invalidate(sentRequestsProvider)
    ..invalidate(myOrdersProvider)
    ..invalidate(orderProvider);
}
