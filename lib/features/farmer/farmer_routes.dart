import 'package:go_router/go_router.dart';

import '../../app/router/route_guard.dart';
import '../../app/shell/nav_config.dart';
import '../../app/shell/placeholder_page.dart';

/// Phase 2 (farmer): farms, fields, crops, the activity log, reporting crop issues and
/// advisories. Replace each `PlaceholderPage` with the real screen and add the pages inside
/// each section (e.g. `/farms/:farmId`) as child routes.
List<RouteBase> farmerRoutes(RouteGuard guard) => [
  guard.route(
    path: Destinations.farms.path,
    roles: Destinations.farms.roles,
    builder: (context, state) => PlaceholderPage(destination: Destinations.farms),
  ),
  guard.route(
    path: Destinations.myIssues.path,
    roles: Destinations.myIssues.roles,
    builder: (context, state) => PlaceholderPage(destination: Destinations.myIssues),
  ),
];
