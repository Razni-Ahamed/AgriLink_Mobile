import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/api/api_error_parser.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/format/formatters.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/dialogs.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../data/approvals_api.dart';
import 'approval_parts.dart';

/// One identity change (full name, NIC or email) shown as old → new, with Approve and Reject.
///
/// Approving asks for the approver's own password in a dialog, like the website. [onDecided]
/// reloads the list, and is also called after "already decided" style failures so the card goes.
class ChangeRequestCard extends ConsumerStatefulWidget {
  const ChangeRequestCard({super.key, required this.request, required this.onDecided});

  final PendingChangeRequest request;
  final VoidCallback onDecided;

  @override
  ConsumerState<ChangeRequestCard> createState() => _ChangeRequestCardState();
}

class _ChangeRequestCardState extends ConsumerState<ChangeRequestCard> {
  bool _rejecting = false;
  bool _busy = false;

  PendingChangeRequest get _request => widget.request;

  Future<void> _approve() async {
    final result = await showDialog<_ApproveResult>(
      context: context,
      builder: (context) => _ApproveDialog(request: _request),
    );
    if (result == null) {
      return;
    }
    // Approved, or it turned out to be already decided: either way the card should go.
    widget.onDecided();
    if (!mounted) {
      return;
    }
    final failure = result.failure;
    if (failure == null) {
      showToast(context, context.l10n.registrationsPendingChangesApproved, tone: ToastTone.success);
    } else {
      showToast(context, failure, tone: ToastTone.error);
    }
  }

  Future<void> _reject(String reason) async {
    setState(() => _busy = true);
    try {
      await ref.read(approvalsApiProvider).rejectChangeRequest(_request.requestId, reason);
      widget.onDecided();
      if (mounted) {
        showToast(
          context,
          context.l10n.registrationsPendingChangesRejected,
          tone: ToastTone.success,
        );
      }
    } on Object catch (error) {
      if (shouldRefreshAfter(error)) {
        widget.onDecided();
      }
      if (mounted) {
        showToast(context, describeError(error, context.l10n), tone: ToastTone.error);
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
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final format = ref.watch(formattersProvider);
    final r = _request;
    final district = r.district;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gaps.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(role: r.role, name: r.fullName, photoUrl: r.profilePhotoUrl, size: 44),
                const SizedBox(width: Gaps.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.fullName, style: textTheme.titleMedium),
                      Text(
                        [
                          r.username,
                          if (district != null && district.isNotEmpty) district,
                        ].join(' · '),
                        style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gaps.xs),
            Text(
              l10n.registrationsPendingChangesRequestedOn(format.dateTime(r.requestedAt)),
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: Gaps.md),
            Text(
              _fieldLabel(l10n, r.changeField),
              style: textTheme.labelMedium?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: Gaps.xs),
            // Both values are written out ("Current: …", "Requested: …") so the change reads
            // without colour or strike-through.
            Text(
              l10n.registrationsPendingChangesOldValue(r.oldValue),
              style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
            Text(
              l10n.registrationsPendingChangesNewValue(r.newValue),
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Gaps.md),
            if (_rejecting)
              RejectReasonForm(
                prompt: l10n.registrationsPendingChangesRejectPrompt,
                placeholder: l10n.registrationsPendingChangesRejectPlaceholder,
                submitLabel: l10n.registrationsPendingChangesRejectSubmit,
                cancelLabel: l10n.registrationsPendingChangesCancel,
                busy: _busy,
                onSubmit: _reject,
                onCancel: () => setState(() => _rejecting = false),
              )
            else
              Wrap(
                alignment: WrapAlignment.end,
                spacing: Gaps.sm,
                runSpacing: Gaps.sm,
                children: [
                  OutlinedButton(
                    key: const Key('reject'),
                    onPressed: _busy ? null : () => setState(() => _rejecting = true),
                    child: Text(l10n.registrationsPendingChangesReject),
                  ),
                  FilledButton(
                    key: const Key('approve'),
                    onPressed: _busy ? null : _approve,
                    child: Text(l10n.registrationsPendingChangesApprove),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

String _fieldLabel(AppLocalizations l10n, ChangeRequestField field) => switch (field) {
  ChangeRequestField.fullName => l10n.registrationsPendingChangesFieldLabelFullName,
  ChangeRequestField.nic => l10n.registrationsPendingChangesFieldLabelNIC,
  ChangeRequestField.email => l10n.registrationsPendingChangesFieldLabelEmail,
};

/// How the approve dialog ended: [failure] is null when it went through, or the server's
/// explanation when the request turned out to be already decided or no longer applicable.
class _ApproveResult {
  const _ApproveResult([this.failure]);

  final String? failure;
}

/// Asks for the approver's password and sends the approval. Pops an [_ApproveResult], or nothing
/// when the approver backed out.
class _ApproveDialog extends ConsumerStatefulWidget {
  const _ApproveDialog({required this.request});

  final PendingChangeRequest request;

  @override
  ConsumerState<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends ConsumerState<_ApproveDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(approvalsApiProvider)
          .approveChangeRequest(widget.request.requestId, _password.text);
      if (mounted) {
        Navigator.of(context).pop(const _ApproveResult());
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final message = describeError(error, l10n);
      // A wrong password is the one failure to fix in place; the others end this request.
      final wrongPassword =
          error is ApiException &&
          error.kind == ApiErrorKind.badRequest &&
          error.serverMessage == 'Current password is incorrect.';
      if (wrongPassword) {
        setState(() {
          _busy = false;
          _error = l10n.registrationsPendingChangesWrongPassword;
        });
      } else if (shouldRefreshAfter(error)) {
        Navigator.of(context).pop(_ApproveResult(message));
      } else {
        setState(() {
          _busy = false;
          _error = message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.registrationsPendingChangesApproveTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.registrationsPendingChangesApprovePrompt),
            const SizedBox(height: Gaps.md),
            PasswordField(
              fieldKey: const Key('approve-password'),
              controller: _password,
              label: l10n.commonFieldsPassword,
              // The server's answer is shown below rather than forced onto the field: a forced
              // error keeps the form invalid until the widget is rebuilt.
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
              validator: (value) =>
                  (value ?? '').isEmpty ? l10n.commonValidationPasswordRequired : null,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _busy ? null : _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: Gaps.sm),
              ErrorBanner(messages: [_error!]),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.registrationsPendingChangesCancel),
        ),
        FilledButton(
          key: const Key('approve-confirm'),
          onPressed: _busy ? null : _submit,
          child: Text(l10n.registrationsPendingChangesApproveConfirm),
        ),
      ],
    );
  }
}
