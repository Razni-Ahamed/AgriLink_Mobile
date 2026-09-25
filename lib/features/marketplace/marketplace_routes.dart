import 'package:go_router/go_router.dart';

import '../../app/router/route_guard.dart';
import '../../app/shell/nav_config.dart';
import '../../app/shell/placeholder_page.dart';
import '../../core/session/role.dart';
import 'marketplace_paths.dart';
import 'presentation/browse_harvests_screen.dart';
import 'presentation/harvest_detail_screen.dart';

/// Phase 3 (marketplace and orders, for farmers and buyers): browsing harvests, listings,
/// purchase requests and orders. Replace each `PlaceholderPage` with the real screen.
List<RouteBase> marketplaceRoutes(RouteGuard guard) => [
  guard.route(
    path: Destinations.marketplace.path,
    roles: Destinations.marketplace.roles,
    builder: (context, state) => const BrowseHarvestsScreen(),
  ),
  for (final destination in [
    Destinations.myListings,
    Destinations.incomingRequests,
    Destinations.sentRequests,
    Destinations.orders,
  ])
    guard.route(
      path: destination.path,
      roles: destination.roles,
      builder: (context, state) => PlaceholderPage(destination: destination),
    ),
  // Last, so the fixed paths above (/marketplace/browse, /marketplace/mine…) match first.
  guard.route(
    path: MarketplacePaths.listingPattern,
    roles: {Role.farmer, Role.buyer, Role.admin},
    builder: (context, state) =>
        HarvestDetailScreen(harvestId: int.tryParse(state.pathParameters['harvestId']!)),
  ),
];
