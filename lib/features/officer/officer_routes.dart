import 'package:go_router/go_router.dart';

import '../../app/router/route_guard.dart';
import '../../app/shell/nav_config.dart';
import '../../app/shell/placeholder_page.dart';
import 'presentation/officer_dashboard_screen.dart';

/// Phase 4 (officer): the dashboard, issue reviews and registration approvals. The pending
/// issues and approvals pages are shared with admins. Replace each `PlaceholderPage` with the
/// real screen.
List<RouteBase> officerRoutes(RouteGuard guard) => [
  guard.route(
    path: Destinations.officerDashboard.path,
    roles: Destinations.officerDashboard.roles,
    builder: (context, state) => const OfficerDashboardScreen(),
  ),
  for (final destination in [
    Destinations.pendingIssues,
    Destinations.reviewedIssues,
    Destinations.approvals,
  ])
    guard.route(
      path: destination.path,
      roles: destination.roles,
      builder: (context, state) => PlaceholderPage(destination: destination),
    ),
];
