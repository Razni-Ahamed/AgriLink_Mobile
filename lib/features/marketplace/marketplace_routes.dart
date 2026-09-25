import 'package:go_router/go_router.dart';

import '../../app/router/route_guard.dart';
import '../../app/shell/nav_config.dart';
import '../../app/shell/placeholder_page.dart';

/// Phase 3 (marketplace and orders, for farmers and buyers): browsing harvests, listings,
/// purchase requests and orders. Replace each `PlaceholderPage` with the real screen.
List<RouteBase> marketplaceRoutes(RouteGuard guard) => [
  for (final destination in [
    Destinations.marketplace,
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
];
