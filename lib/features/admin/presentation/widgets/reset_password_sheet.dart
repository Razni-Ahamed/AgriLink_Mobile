import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/api/api_error_parser.dart';
import '../../../../core/validation/validators.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/dialogs.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../data/admin_api.dart';
import '../../data/admin_models.dart';
import 'sheet_frame.dart';

/// Sets a new password for another user. Follows the same rules as registration (the checklist),
/// asks to confirm, naming the user, then closes with `true`.
///
/// The password only ever lives in these two fields and in the one request. It is never logged,
/// stored or shown again.
class ResetPasswordSheet extends ConsumerStatefulWidget {
  const ResetPasswordSheet({super.key, required this.user});

  final AdminUser user;

  @override
  ConsumerState<ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends ConsumerState<ResetPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _saving = false;
  List<String> _errors = const [];

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final l10n = context.l10n;
    final user = widget.user;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.adminUsersDetailResetConfirmTitle(user.fullName),
      message: l10n.adminUsersDetailResetConfirmMessage,
      confirmLabel: l10n.ordersAdminResetPasswordSubmit,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() {
      _saving = true;
      _errors = const [];
    });
    try {
      await ref.read(adminApiProvider).resetPassword(user.userId, _password.text);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final parsed = parseApiError(
        error,
        context.l10n,
        generic: (l) => l.ordersAdminResetPasswordError,
      );
      setState(() {
        _saving = false;
        _errors = [...parsed.generalErrors, ...parsed.fieldErrors.values];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final v = FormValidators(l10n);
    return SheetFrame(
      title: l10n.ordersAdminResetPassword,
      children: [
        Text(
          l10n.ordersAdminResetPasswordFor(widget.user.fullName),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: Gaps.md),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PasswordField(
                fieldKey: const Key('reset-password'),
                controller: _password,
                label: l10n.ordersAdminNewPassword,
                isNewPassword: true,
                validator: v.newPassword(),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Gaps.sm),
              PasswordChecklist(password: _password.text),
              const SizedBox(height: Gaps.md),
              PasswordField(
                fieldKey: const Key('reset-confirm'),
                controller: _confirm,
                label: l10n.ordersAdminConfirmNewPassword,
                isNewPassword: true,
                textInputAction: TextInputAction.done,
                validator: v.confirmPassword(() => _password.text),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gaps.md),
        if (_errors.isNotEmpty) ErrorBanner(messages: _errors),
        const SizedBox(height: Gaps.sm),
        LoadingButton(
          key: const Key('reset-save'),
          label: l10n.ordersAdminResetPasswordSubmit,
          loadingLabel: l10n.ordersAdminResettingPassword,
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
