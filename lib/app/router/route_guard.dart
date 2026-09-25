import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/role.dart';
import 'app_routes.dart';

/// Builds routes that only some roles may open. Someone typing or deep-linking into another
/// role's page is sent to their own home instead, like the website's `RequireRole`.
///
/// Feature route files receive one from the router:
///
/// ```dart
/// List<RouteBase> farmerRoutes(RouteGuard guard) => [
///   guard.route(
///     path: AppRoutes.farms,
///     roles: {Role.farmer},
///     builder: (context, state) => const FarmsScreen(),
///     routes: [
///       // /farms/12: the guard above covers pages inside the section too.
///       GoRoute(path: ':farmId', builder: (context, state) => FarmDetailScreen(...)),
///     ],
///   ),
/// ];
/// ```
class RouteGuard {
  const RouteGuard(this._currentRole);

  final Role? Function() _currentRole;

  GoRoute route({
    required String path,
    required Set<Role> roles,
    required Widget Function(BuildContext context, GoRouterState state) builder,
    List<RouteBase> routes = const [],
  }) {
    return GoRoute(
      path: path,
      builder: builder,
      routes: routes,
      redirect: (context, state) => redirectForRole(_currentRole(), roles),
    );
  }
}

/// Null when [role] may open a page for [allowed]; otherwise the role's home. A signed-out
/// user (null role) is handled by the router's top-level redirect.
String? redirectForRole(Role? role, Set<Role> allowed) {
  if (role == null || allowed.contains(role)) {
    return null;
  }
  return homePathFor(role);
}
