import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/current_user.dart';

/// Shown at start-up: restores the stored session, loads the profile, then goes to the role's
/// home. With no session, or one the server rejects, the router moves on to the login screen.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Object? _error;
  bool _slow = false;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _slow = false;
    });
    _slowTimer?.cancel();
    // The free hosting tier can take a while to wake up; say so rather than look stuck.
    _slowTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _slow = true);
      }
    });

    final session = ref.read(sessionControllerProvider.notifier);
    if (ref.read(sessionControllerProvider).status == SessionStatus.restoring) {
      await session.restore();
    }
    final state = ref.read(sessionControllerProvider);
    if (!state.isSignedIn) {
      return; // The router sends a signed-out user to the login screen.
    }
    try {
      await ref.read(currentUserProvider.future);
      if (mounted) {
        context.go(homePathFor(state.role!));
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final rejected =
          error is ApiException &&
          (error.kind == ApiErrorKind.forbidden || error.kind == ApiErrorKind.notFound);
      if (rejected) {
        // Like the website: a deactivated or deleted account ends the session. A 401 has
        // already been handled by the API client.
        await session.signOut(SignOutReason.sessionExpired);
        return;
      }
      setState(() => _error = error);
    } finally {
      _slowTimer?.cancel();
    }
  }

  Future<void> _retry() async {
    ref.invalidate(currentUserProvider);
    await _start();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: _error != null
            ? ErrorView(error: _error!, onRetry: _retry)
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(Gaps.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.eco, size: 64, color: context.colors.forest),
                      const SizedBox(height: Gaps.md),
                      Text(
                        l10n.commonAppName,
                        style: textTheme.headlineMedium?.copyWith(color: context.colors.forest),
                      ),
                      const SizedBox(height: Gaps.lg),
                      const CircularProgressIndicator(),
                      const SizedBox(height: Gaps.md),
                      Text(
                        _slow ? l10n.commonErrorsSlowServer : l10n.authSplashLoading,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
