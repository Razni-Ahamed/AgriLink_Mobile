import 'package:go_router/go_router.dart';

import '../../app/router/route_guard.dart';
import '../../app/shell/nav_config.dart';
import 'presentation/profile_edit_screen.dart';
import 'presentation/profile_screen.dart';
import 'presentation/security_screen.dart';

/// The profile and security settings, for every role. `/profile/edit` and `/profile/security`
/// open on top of the profile, with a back button.
List<RouteBase> accountRoutes(RouteGuard guard) => [
  guard.route(
    path: Destinations.profile.path,
    roles: Destinations.profile.roles,
    builder: (context, state) => const ProfileScreen(),
    routes: [
      GoRoute(path: 'edit', builder: (context, state) => const ProfileEditScreen()),
      GoRoute(path: 'security', builder: (context, state) => const SecurityScreen()),
    ],
  ),
];
