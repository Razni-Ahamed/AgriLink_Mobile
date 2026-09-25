import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/format/formatters.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/account_models.dart';

/// Whether a change applies straight away or waits for an officer's or admin's approval.
enum SecurityChangeMode { direct, request }

/// One detail on the security screen, like the website's SecurityFieldRow: the value in use,
/// a pending request (with Withdraw), the latest rejection, and, once unlocked, an input with
/// the right save action.
class SecurityFieldRow extends ConsumerStatefulWidget {
  const SecurityFieldRow({
    super.key,
    required this.label,
    required this.currentValue,
    required this.mode,
    required this.unlocked,
    required this.onSubmit,
    this.clearable = false,
    this.keyboardType,
    this.pending,
    this.latestRejection,
    this.onWithdraw,
    this.busy = false,
    this.onActivity,
  });

  final String label;

  /// The value in effect. A pending request never changes it.
  final String? currentValue;
  final SecurityChangeMode mode;
  final bool unlocked;

  /// Returns true when the change went through, so the input can be cleared.
  final Future<bool> Function(String value) onSubmit;

  /// Officer/admin phone only: submitting it empty clears the value.
  final bool clearable;
  final TextInputType? keyboardType;
  final ChangeRequest? pending;
  final ChangeRequest? latestRejection;
  final ValueChanged<ChangeRequest>? onWithdraw;
  final bool busy;
  final VoidCallback? onActivity;

  @override
  ConsumerState<SecurityFieldRow> createState() => _SecurityFieldRowState();
}

class _SecurityFieldRowState extends ConsumerState<SecurityFieldRow> {
  final _value = TextEditingController();

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _value.text.trim();
    // Empty keeps the current value, except for a clearable field where it means "clear it".
    if (value.isEmpty && !widget.clearable) {
      return;
    }
    if (await widget.onSubmit(value) && mounted) {
      _value.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final format = ref.watch(formattersProvider);
    final current = widget.currentValue?.trim();
    final pending = widget.pending;
    final rejection = widget.latestRejection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label, style: textTheme.bodySmall),
                  Text(
                    current == null || current.isEmpty ? l10n.authProfileGeneralNotSet : current,
                    style: textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            if (pending != null)
              StatusBadge(label: l10n.authProfileSecurityPendingApproval, tone: BadgeTone.warning),
          ],
        ),
        if (pending != null) ...[
          const SizedBox(height: Gaps.sm),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.tint(colors.harvest),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.authProfileSecurityPendingValue(pending.newValue))),
                  TextButton(
                    onPressed: widget.busy ? null : () => widget.onWithdraw?.call(pending),
                    child: Text(l10n.authProfileSecurityWithdraw),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (rejection != null) ...[
          const SizedBox(height: Gaps.xs),
          Text(
            l10n.authProfileSecurityRecentlyRejected(
              rejection.newValue,
              format.date(rejection.decidedAt ?? rejection.requestedAt),
              rejection.rejectionReason ?? '',
            ),
            style: textTheme.bodySmall?.copyWith(color: colors.danger),
          ),
        ],
        if (widget.unlocked && pending == null) ...[
          const SizedBox(height: Gaps.sm),
          TextField(
            key: Key('security-input-${widget.label}'),
            controller: _value,
            keyboardType: widget.keyboardType,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.authProfileSecurityNewValueLabel(widget.label),
              hintText: current,
            ),
            onChanged: (_) => widget.onActivity?.call(),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: Gaps.sm),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              key: Key('security-submit-${widget.label}'),
              onPressed: widget.busy ? null : _submit,
              child: Text(
                widget.mode == SecurityChangeMode.direct
                    ? l10n.authProfileSecuritySave
                    : l10n.authProfileSecuritySubmitForApproval,
              ),
            ),
          ),
          if (widget.mode == SecurityChangeMode.request)
            Text(l10n.authProfileSecurityApprovalNote, style: textTheme.bodySmall),
        ],
      ],
    );
  }
}
