import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/validation/validators.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/form_fields.dart';
import '../application/auth_service.dart';
import 'widgets/auth_layout.dart';

/// One sign-in screen for every role. After a successful sign-in the router takes the user to
/// their role's home.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _submitting = false;
  bool _slow = false;
  LoginFailure? _failure;
  Timer? _slowTimer;

  @override
  void dispose() {
    _slowTimer?.cancel();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    ref.read(sessionControllerProvider.notifier).clearSignOutReason();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _failure = null;
      _slow = false;
    });
    _slowTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _slow = true);
      }
    });
    try {
      await ref.read(authServiceProvider).signIn(email: _email.text, password: _password.text);
      // Signed in: the router leaves this screen.
    } on LoginFailure catch (failure) {
      if (mounted) {
        setState(() => _failure = failure);
      }
    } finally {
      _slowTimer?.cancel();
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final validators = FormValidators(l10n);
    final signOutReason = ref.watch(sessionControllerProvider.select((s) => s.signOutReason));

    return AuthLayout(
      title: l10n.authLoginSubtitle,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (signOutReason == SignOutReason.sessionExpired) ...[
                InfoBanner(message: l10n.commonErrorsSessionExpired),
                const SizedBox(height: Gaps.md),
              ],
              AppTextField(
                fieldKey: const Key('login-email'),
                controller: _email,
                label: l10n.commonFieldsEmail,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email, AutofillHints.username],
                autocorrect: false,
                validator: validators.email(),
              ),
              const SizedBox(height: Gaps.md),
              PasswordField(
                fieldKey: const Key('login-password'),
                controller: _password,
                label: l10n.commonFieldsPassword,
                validator: validators.passwordEntered(),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              if (_failure != null) ...[
                const SizedBox(height: Gaps.md),
                _FailureMessage(failure: _failure!, onRetry: _submit),
              ],
              const SizedBox(height: Gaps.lg),
              LoadingButton(
                key: const Key('login-submit'),
                label: l10n.authLoginSubmit,
                loadingLabel: l10n.authLoginSubmitting,
                loading: _submitting,
                onPressed: _submit,
              ),
              if (_submitting && _slow) ...[
                const SizedBox(height: Gaps.sm),
                Text(
                  l10n.commonErrorsSlowServer,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: Gaps.md),
              AuthSwitchLink(
                prompt: l10n.authLoginNoAccount,
                linkLabel: l10n.authLoginRegisterLink,
                onPressed: () => context.go(AppRoutes.register),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FailureMessage extends StatelessWidget {
  const _FailureMessage({required this.failure, required this.onRetry});

  final LoginFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (failure) {
      LoginFailureInvalidCredentials() => ErrorBanner(messages: [l10n.authLoginError]),
      LoginFailurePending() => _PendingBanner(
        title: l10n.authLoginPendingTitle,
        message: l10n.authLoginPendingMessage,
      ),
      LoginFailureRejected(:final reason) => ErrorBanner(
        title: l10n.authLoginRejectedTitle,
        messages: [
          l10n.authLoginRejectedMessage,
          if (reason != null && reason.trim().isNotEmpty)
            l10n.authLoginRejectedReason(reason.trim()),
        ],
      ),
      LoginFailureNetwork(:final timedOut) => ErrorBanner(
        messages: [l10n.commonErrorsNetwork, if (timedOut) l10n.commonErrorsSlowServer],
        action: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.commonActionsRetry),
        ),
      ),
      LoginFailureOther(:final serverMessage) => ErrorBanner(
        messages: [serverMessage ?? l10n.commonErrorsGeneric],
      ),
    };
  }
}

/// A pending account isn't an error; show it in the calmer gold of a waiting state.
class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.tint(colors.harvest),
          border: Border.all(color: colors.harvest.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(kRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.hourglass_top, color: colors.textPrimary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleSmall),
                    Text(message, style: textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
