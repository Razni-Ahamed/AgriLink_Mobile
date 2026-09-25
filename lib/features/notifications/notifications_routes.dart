import 'package:go_router/go_router.dart';

import '../../app/router/route_guard.dart';
import '../../app/shell/nav_config.dart';
import '../../app/shell/placeholder_page.dart';

/// The notifications list, for every role.
List<RouteBase> notificationsRoutes(RouteGuard guard) => [
  guard.route(
    path: Destinations.notifications.path,
    roles: Destinations.notifications.roles,
    builder: (context, state) => PlaceholderPage(destination: Destinations.notifications),
  ),
];
