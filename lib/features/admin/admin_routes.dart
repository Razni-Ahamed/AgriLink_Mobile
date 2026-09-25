import 'package:go_router/go_router.dart';

import '../../app/router/route_guard.dart';
import '../../app/shell/nav_config.dart';
import '../../app/shell/placeholder_page.dart';
import 'presentation/admin_dashboard_screen.dart';
import 'presentation/create_user_screen.dart';
import 'presentation/departments_screen.dart';
import 'presentation/user_detail_screen.dart';
import 'presentation/users_screen.dart';

/// Phase 4 (admin): the dashboard, users, departments, all issues and the audit log. Replace
/// each `PlaceholderPage` with the real screen.
List<RouteBase> adminRoutes(RouteGuard guard) => [
  guard.route(
    path: Destinations.adminDashboard.path,
    roles: Destinations.adminDashboard.roles,
    builder: (context, state) => const AdminDashboardScreen(),
  ),
  guard.route(
    path: Destinations.users.path,
    roles: Destinations.users.roles,
    builder: (context, state) => const UsersScreen(),
    routes: [
      // Before ':userId', or "new" would be read as a user id.
      GoRoute(path: 'new', builder: (context, state) => const CreateUserScreen()),
      GoRoute(
        path: ':userId',
        builder: (context, state) =>
            UserDetailScreen(userId: int.tryParse(state.pathParameters['userId']!) ?? -1),
      ),
    ],
  ),
  guard.route(
    path: Destinations.departments.path,
    roles: Destinations.departments.roles,
    builder: (context, state) => const DepartmentsScreen(),
  ),
  for (final destination in [Destinations.allIssues, Destinations.auditLog])
    guard.route(
      path: destination.path,
      roles: destination.roles,
      builder: (context, state) => PlaceholderPage(destination: destination),
    ),
];
