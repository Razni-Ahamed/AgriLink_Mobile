import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/api/api_error_parser.dart';
import '../../../core/session/role.dart';
import '../../../core/session/session.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/validation/validators.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/application/current_user.dart';
import '../../auth/data/auth_models.dart';
import '../application/security_settings.dart';
import '../data/account_api.dart';
import '../data/account_models.dart';
import 'widgets/change_password_form.dart';
import 'widgets/security_field_row.dart';

/// The security settings, as on the website's Security tab: read-only until the user enters
/// their current password again. Then direct changes (the phone; for an admin also the full
/// name and email) save at once, and the others open a request for approval.
///
/// The password typed to unlock is kept only in this screen's memory: it is forgotten when the
/// screen closes, on "Done editing", and after 5 minutes without an edit.
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  static const unlockTimeout = Duration(minutes: 5);

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  final _unlockInput = TextEditingController();
  bool _showUnlockForm = false;
  bool _verifying = false;
  bool _busy = false;
  String? _unlockError;

  /// The re-entered password, while unlocked.
  String? _password;
  Timer? _lockTimer;

  bool get _unlocked => _password != null;

  @override
  void dispose() {
    _lockTimer?.cancel();
    _unlockInput.dispose();
    super.dispose();
  }

  void _lock({bool timedOut = false}) {
    _lockTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _password = null;
      _showUnlockForm = false;
      _unlockError = null;
      _unlockInput.clear();
    });
    if (timedOut) {
      showToast(context, context.l10n.authProfileSecurityAutoLocked);
    }
  }

  void _resetLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = Timer(SecurityScreen.unlockTimeout, () => _lock(timedOut: true));
  }

  Future<void> _unlock() async {
    final l10n = context.l10n;
    if (_unlockInput.text.isEmpty) {
      setState(() => _unlockError = l10n.commonValidationPasswordRequired);
      return;
    }
    setState(() {
      _verifying = true;
      _unlockError = null;
    });
    try {
      await ref.read(accountApiProvider).verifyPassword(_unlockInput.text);
      setState(() {
        _password = _unlockInput.text;
        _showUnlockForm = false;
        _unlockInput.clear();
      });
      _resetLockTimer();
    } on Object catch (error) {
      final parsed = parseApiError(error, l10n, generic: (l) => l.authProfileSecurityWrongPassword);
      setState(() => _unlockError = parsed.generalErrors.firstOrNull);
    } finally {
      if (mounted) {
        setState(() => _verifying = false);
      }
    }
  }

  /// Runs a change, reloads the settings and reports the result. True when it went through.
  Future<bool> _change(Future<String> Function() action) async {
    final l10n = context.l10n;
    _resetLockTimer();
    setState(() => _busy = true);
    try {
      final message = await action();
      ref.invalidate(securitySettingsProvider);
      if (mounted) {
        showToast(context, message, tone: ToastTone.success);
      }
      return true;
    } on Object catch (error) {
      if (mounted) {
        final parsed = parseApiError(error, l10n, generic: (l) => l.authProfileSecuritySaveError);
        showToast(context, parsed.summary, tone: ToastTone.error);
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _savePhone(String value) {
    final l10n = context.l10n;
    return _change(() async {
      final profile = await ref
          .read(accountApiProvider)
          .updatePhone(currentPassword: _password!, phoneNumber: normalizePhone(value));
      ref.read(currentUserProvider.notifier).set(profile);
      return l10n.authProfileSecurityPhoneUpdated;
    });
  }

  Future<bool> _requestChange(ChangeRequestField field, String value, bool isAdmin) {
    final l10n = context.l10n;
    return _change(() async {
      final result = await ref
          .read(accountApiProvider)
          .requestChange(
            currentPassword: _password!,
            field: field,
            newValue: field == ChangeRequestField.nic ? normalizeNic(value) : value,
            isAdmin: isAdmin,
          );
      switch (result) {
        case ChangeAppliedWithNewToken(:final auth):
          // An admin's own email change rotates the security stamp, like a password change.
          await ref
              .read(sessionControllerProvider.notifier)
              .signIn(Session(token: auth.token, role: auth.role));
          return l10n.authProfileSecuritySaved;
        case ChangeApplied(:final profile):
          ref.read(currentUserProvider.notifier).set(profile);
          return l10n.authProfileSecuritySaved;
        case ChangeRequested():
          return l10n.authProfileSecurityRequestSubmitted;
      }
    });
  }

  Future<void> _withdraw(ChangeRequest request) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await ref.read(accountApiProvider).withdrawChangeRequest(request.requestId);
      ref.invalidate(securitySettingsProvider);
      if (mounted) {
        showToast(context, l10n.authProfileSecurityWithdrawn, tone: ToastTone.success);
      }
    } on Object {
      if (mounted) {
        showToast(context, l10n.authProfileSecurityWithdrawError, tone: ToastTone.error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = ref.watch(currentUserProvider).value;
    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.authProfileTabsSecurity),
      body: AsyncValueView(
        value: ref.watch(securitySettingsProvider),
        loadingMessage: l10n.authProfileLoading,
        onRetry: () => ref.invalidate(securitySettingsProvider),
        data: (settings) => user == null
            ? LoadingView(message: l10n.authProfileLoading)
            : _buildSettings(context, settings, user),
      ),
    );
  }

  Widget _buildSettings(BuildContext context, SecuritySettings settings, UserProfile user) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final isAdmin = user.role == Role.admin;
    final canChange = settings.canChange;
    final canRequest = settings.canRequest;
    const divider = Padding(
      padding: EdgeInsets.symmetric(vertical: Gaps.md),
      child: Divider(),
    );

    SecurityChangeMode modeFor(SecurityCapability capability) =>
        canChange.contains(capability) ? SecurityChangeMode.direct : SecurityChangeMode.request;
    bool shows(SecurityCapability capability) =>
        canChange.contains(capability) || canRequest.contains(capability);

    Widget requestRow({
      required SecurityCapability capability,
      required ChangeRequestField field,
      required String label,
      required String? value,
      TextInputType? keyboardType,
    }) => SecurityFieldRow(
      label: label,
      currentValue: value,
      mode: modeFor(capability),
      unlocked: _unlocked,
      keyboardType: keyboardType,
      busy: _busy,
      pending: settings.pendingFor(field),
      latestRejection: settings.latestRejectionFor(field),
      onWithdraw: _withdraw,
      onActivity: _resetLockTimer,
      onSubmit: (value) => _requestChange(field, value, isAdmin),
    );

    return ListView(
      padding: const EdgeInsets.all(Gaps.md),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gaps.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canChange.contains(SecurityCapability.password)) ...[
                  Text(l10n.authProfileSecurityPasswordHeading, style: textTheme.titleSmall),
                  Text('••••••••', style: textTheme.bodyLarge!.mono),
                  if (_unlocked) ...[
                    const SizedBox(height: Gaps.md),
                    ChangePasswordForm(onActivity: _resetLockTimer),
                  ],
                  divider,
                ],
                if (canChange.contains(SecurityCapability.phone)) ...[
                  SecurityFieldRow(
                    label: l10n.commonFieldsPhoneNumber,
                    currentValue: settings.phoneNumber,
                    mode: SecurityChangeMode.direct,
                    unlocked: _unlocked,
                    clearable: user.role == Role.officer || user.role == Role.admin,
                    keyboardType: TextInputType.phone,
                    busy: _busy,
                    onActivity: _resetLockTimer,
                    onSubmit: _savePhone,
                  ),
                  divider,
                ],
                if (shows(SecurityCapability.fullName)) ...[
                  requestRow(
                    capability: SecurityCapability.fullName,
                    field: ChangeRequestField.fullName,
                    label: l10n.commonFieldsFullName,
                    value: user.fullName,
                  ),
                  divider,
                ],
                if (canRequest.contains(SecurityCapability.nic)) ...[
                  requestRow(
                    capability: SecurityCapability.nic,
                    field: ChangeRequestField.nic,
                    label: l10n.commonFieldsNic,
                    value: settings.nic,
                  ),
                  divider,
                ],
                if (shows(SecurityCapability.email))
                  requestRow(
                    capability: SecurityCapability.email,
                    field: ChangeRequestField.email,
                    label: l10n.commonFieldsEmail,
                    value: user.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gaps.md),
        if (!_unlocked && !_showUnlockForm)
          FilledButton.icon(
            key: const Key('unlock-security'),
            onPressed: () => setState(() => _showUnlockForm = true),
            icon: const Icon(Icons.lock_open_outlined),
            label: Text(l10n.authProfileSecurityEditSecurityDetails),
          ),
        if (!_unlocked && _showUnlockForm)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gaps.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.authProfileSecurityUnlockPrompt, style: textTheme.bodyMedium),
                  const SizedBox(height: Gaps.md),
                  PasswordField(
                    fieldKey: const Key('unlock-password'),
                    controller: _unlockInput,
                    label: l10n.commonFieldsPassword,
                    serverError: _unlockError,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() => _unlockError = null),
                    onFieldSubmitted: (_) => _unlock(),
                  ),
                  const SizedBox(height: Gaps.md),
                  LoadingButton(
                    key: const Key('unlock-submit'),
                    label: l10n.authProfileSecurityUnlock,
                    loading: _verifying,
                    onPressed: _unlock,
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _showUnlockForm = false;
                      _unlockError = null;
                      _unlockInput.clear();
                    }),
                    child: Text(l10n.authProfileEditCancel),
                  ),
                ],
              ),
            ),
          ),
        if (_unlocked)
          OutlinedButton.icon(
            key: const Key('lock-security'),
            onPressed: _lock,
            icon: const Icon(Icons.lock_outline),
            label: Text(l10n.authProfileSecurityDoneEditing),
          ),
        const SizedBox(height: Gaps.lg),
      ],
    );
  }
}
