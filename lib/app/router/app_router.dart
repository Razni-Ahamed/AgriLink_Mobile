import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/role.dart';
import '../../core/session/session_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/pending_approval_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../shell/coming_soon_screen.dart';
import 'app_routes.dart';

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

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: sessionChanges,
    redirect: (context, state) =>
        redirectFor(ref.read(sessionControllerProvider), state.matchedLocation),
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
      for (final role in Role.values)
        GoRoute(
          path: homePathFor(role),
          builder: (context, state) => const Scaffold(
            body: SafeArea(child: ComingSoonScreen(icon: Icons.home_outlined)),
          ),
        ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    sessionChanges.dispose();
  });
  return router;
});
