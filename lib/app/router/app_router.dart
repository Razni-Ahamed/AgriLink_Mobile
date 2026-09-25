import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/role.dart';
import '../../core/session/session_controller.dart';
import '../../features/account/account_routes.dart';
import '../../features/admin/admin_routes.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/pending_approval_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/farmer/farmer_routes.dart';
import '../../features/marketplace/marketplace_routes.dart';
import '../../features/notifications/notifications_routes.dart';
import '../../features/officer/officer_routes.dart';
import '../shell/app_shell.dart';
import '../shell/more_screen.dart';
import '../shell/nav_config.dart';
import '../shell/not_found_screen.dart';
import 'app_routes.dart';
import 'route_guard.dart';

/// Where the router sends the user for [location], or null to stay. Runs on every navigation
/// and whenever the session changes.
String? redirectFor(SessionState session, String location) {
  switch (session.status) {
    case SessionStatus.restoring:
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case SessionStatus.signedOut:
      final isPublic = AppRoutes.signedOut.contains(location) && location != AppRoutes.splash;
      return isPublic ? null : AppRoutes.login;
    case SessionStatus.signedIn:
      // The splash screen stays until the profile has loaded, then moves on by itself.
      if (location == AppRoutes.splash) {
        return null;
      }
      if (AppRoutes.signedOut.contains(location)) {
        return homePathFor(session.role!);
      }
      return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final sessionChanges = ValueNotifier<int>(0);
  ref.listen(sessionControllerProvider, (_, _) => sessionChanges.value++);
  final guard = RouteGuard(() => ref.read(sessionControllerProvider).role);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: sessionChanges,
    redirect: (context, state) =>
        redirectFor(ref.read(sessionControllerProvider), state.matchedLocation),
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.register,
        // `?role=Buyer` opens the form on the buyer fields, like the website.
        builder: (context, state) => RegisterScreen(
          initialRole: Role.fromApi(state.uri.queryParameters['role']) ?? Role.farmer,
        ),
      ),
      GoRoute(
        path: AppRoutes.registerPending,
        builder: (context, state) => const PendingApprovalScreen(),
      ),
      // Every signed-in page, inside the role's bottom navigation. Each feature adds its own
      // routes, guarded by role, in its own file.
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          ...farmerRoutes(guard),
          ...marketplaceRoutes(guard),
          ...officerRoutes(guard),
          ...adminRoutes(guard),
          ...notificationsRoutes(guard),
          ...accountRoutes(guard),
          guard.route(
            path: AppRoutes.more,
            roles: Destinations.more.roles,
            builder: (context, state) => const MoreScreen(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    sessionChanges.dispose();
  });
  return router;
});
