import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/form_fields.dart';

/// After a failed decision, whether the list is probably out of date ("already decided", the
/// request is gone, the email was taken meanwhile) and worth reloading. A lost connection isn't:
/// the card is still there to try again.
bool shouldRefreshAfter(Object error) =>
    error is ApiException &&
    (error.kind == ApiErrorKind.badRequest ||
        error.kind == ApiErrorKind.conflict ||
        error.kind == ApiErrorKind.notFound);

/// A red button for the reject action, like the confirm dialog's destructive button.
class RejectButton extends StatelessWidget {
  const RejectButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: colors.danger,
        foregroundColor: colors.surface,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

/// The reason box of a rejection, shared by both queues. The reason is required (the server
/// rejects an empty one) and at most 500 characters.
class RejectReasonForm extends StatefulWidget {
  const RejectReasonForm({
    super.key,
    required this.prompt,
    required this.placeholder,
    required this.submitLabel,
    required this.cancelLabel,
    required this.onSubmit,
    required this.onCancel,
    this.hint,
    this.busy = false,
  });

  final String prompt;
  final String placeholder;
  final String? hint;
  final String submitLabel;
  final String cancelLabel;
  final bool busy;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;

  @override
  State<RejectReasonForm> createState() => _RejectReasonFormState();
}

class _RejectReasonFormState extends State<RejectReasonForm> {
  static const _maxLength = 500;

  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onSubmit(_reason.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            fieldKey: const Key('reject-reason'),
            controller: _reason,
            label: widget.prompt,
            hint: widget.placeholder,
            helper: widget.hint,
            maxLines: 3,
            maxLength: _maxLength,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            enabled: !widget.busy,
            validator: (value) =>
                (value ?? '').trim().isEmpty ? l10n.registrationsPendingReasonRequired : null,
          ),
          const SizedBox(height: Gaps.sm),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: Gaps.sm,
            runSpacing: Gaps.sm,
            children: [
              TextButton(
                key: const Key('reject-cancel'),
                onPressed: widget.busy ? null : widget.onCancel,
                child: Text(widget.cancelLabel),
              ),
              RejectButton(
                key: const Key('reject-submit'),
                label: widget.submitLabel,
                onPressed: widget.busy ? null : _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
