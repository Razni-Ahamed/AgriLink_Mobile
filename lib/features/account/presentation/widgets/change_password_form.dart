import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/api/api_error_parser.dart';
import '../../../../core/session/session.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../core/validation/validators.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/dialogs.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../data/account_api.dart';

/// Changing the password. On success the new token the API returns replaces the stored one:
/// the change rotates the security stamp, so the old token stops working straight away.
class ChangePasswordForm extends ConsumerStatefulWidget {
  const ChangePasswordForm({super.key, this.onActivity});

  /// Called while typing, so the security screen stays unlocked.
  final VoidCallback? onActivity;

  @override
  ConsumerState<ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends ConsumerState<ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final auth = await ref
          .read(accountApiProvider)
          .changePassword(currentPassword: _current.text, newPassword: _new.text);
      await ref
          .read(sessionControllerProvider.notifier)
          .signIn(Session(token: auth.token, role: auth.role));
      _formKey.currentState!.reset();
      for (final controller in [_current, _new, _confirm]) {
        controller.clear();
      }
      if (mounted) {
        showToast(context, l10n.authChangePasswordSuccess, tone: ToastTone.success);
      }
    } on Object catch (error) {
      if (mounted) {
        final parsed = parseApiError(error, l10n, generic: (l) => l.authChangePasswordError);
        showToast(context, parsed.summary, tone: ToastTone.error);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final v = FormValidators(l10n);
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PasswordField(
              fieldKey: const Key('current-password'),
              controller: _current,
              label: l10n.authChangePasswordCurrentPassword,
              validator: v.passwordEntered(),
              onChanged: (_) => widget.onActivity?.call(),
            ),
            const SizedBox(height: Gaps.md),
            PasswordField(
              fieldKey: const Key('new-password'),
              controller: _new,
              label: l10n.authChangePasswordNewPassword,
              isNewPassword: true,
              validator: v.newPassword(),
              onChanged: (_) {
                widget.onActivity?.call();
                setState(() {});
              },
            ),
            const SizedBox(height: Gaps.sm),
            PasswordChecklist(password: _new.text),
            const SizedBox(height: Gaps.md),
            PasswordField(
              fieldKey: const Key('confirm-new-password'),
              controller: _confirm,
              label: l10n.authChangePasswordConfirmNewPassword,
              isNewPassword: true,
              textInputAction: TextInputAction.done,
              validator: (value) => (value ?? '').isEmpty
                  ? l10n.commonValidationPasswordRequired
                  : value == _new.text
                  ? null
                  : l10n.commonValidationPasswordsMustMatch,
              onChanged: (_) => widget.onActivity?.call(),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: Gaps.md),
            LoadingButton(
              key: const Key('change-password-submit'),
              label: l10n.authChangePasswordSubmit,
              loadingLabel: l10n.authChangePasswordSubmitting,
              loading: _saving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
