import 'package:go_router/go_router.dart';

import '../../app/router/route_guard.dart';
import '../../app/shell/nav_config.dart';
import '../../app/shell/placeholder_page.dart';
import 'presentation/admin_dashboard_screen.dart';

/// Phase 4 (admin): the dashboard, users, departments, all issues and the audit log. Replace
/// each `PlaceholderPage` with the real screen.
List<RouteBase> adminRoutes(RouteGuard guard) => [
  guard.route(
    path: Destinations.adminDashboard.path,
    roles: Destinations.adminDashboard.roles,
    builder: (context, state) => const AdminDashboardScreen(),
  ),
  for (final destination in [
    Destinations.allIssues,
    Destinations.users,
    Destinations.departments,
    Destinations.auditLog,
  ])
    guard.route(
      path: destination.path,
      roles: destination.roles,
      builder: (context, state) => PlaceholderPage(destination: destination),
    ),
];
