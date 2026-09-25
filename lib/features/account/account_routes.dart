import 'package:go_router/go_router.dart';

import '../../app/router/route_guard.dart';
import '../../app/shell/nav_config.dart';
import '../../app/shell/placeholder_page.dart';

/// The profile and security settings, for every role.
List<RouteBase> accountRoutes(RouteGuard guard) => [
  guard.route(
    path: Destinations.profile.path,
    roles: Destinations.profile.roles,
    builder: (context, state) => PlaceholderPage(destination: Destinations.profile),
  ),
];
