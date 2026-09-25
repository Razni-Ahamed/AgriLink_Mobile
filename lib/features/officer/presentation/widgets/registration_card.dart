import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/api/api_error_parser.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/session/role.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/labels.dart';
import '../../../../shared/widgets/dialogs.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../application/pending_registrations.dart';
import '../../data/approvals_api.dart';
import 'approval_parts.dart';

/// One application: who applied and with what details, and the two decisions. Approving asks
/// first; rejecting needs a reason, which the applicant sees when they try to sign in.
class RegistrationCard extends ConsumerStatefulWidget {
  const RegistrationCard({super.key, required this.application});

  final PendingRegistration application;

  @override
  ConsumerState<RegistrationCard> createState() => _RegistrationCardState();
}

class _RegistrationCardState extends ConsumerState<RegistrationCard> {
  bool _rejecting = false;
  bool _busy = false;

  PendingRegistration get _application => widget.application;

  Future<void> _decide(Future<void> Function() action, String Function() success) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(pendingRegistrationsProvider);
      if (mounted) {
        showToast(context, success(), tone: ToastTone.success);
      }
    } on Object catch (error) {
      if (shouldRefreshAfter(error)) {
        ref.invalidate(pendingRegistrationsProvider);
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

  Future<void> _approve() async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.registrationsPendingApproveConfirmTitle,
      message: l10n.registrationsPendingApproveConfirmMessage(
        _application.fullName,
        roleLabel(l10n, _application.role.apiName),
      ),
      confirmLabel: l10n.registrationsPendingApprove,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _decide(
      () => ref.read(approvalsApiProvider).approveRegistration(_application.userId),
      () => l10n.registrationsPendingApproved(_application.fullName),
    );
  }

  Future<void> _reject(String reason) => _decide(
    () => ref.read(approvalsApiProvider).rejectRegistration(_application.userId, reason),
    () => context.l10n.registrationsPendingRejected(_application.fullName),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final format = ref.watch(formattersProvider);
    final a = _application;
    final details = [
      l10n.registrationsPendingDistrict(a.district),
      if (a.nic != null && a.nic!.isNotEmpty) l10n.registrationsPendingNic(a.nic!),
      if (a.isFarmer) ...[
        l10n.registrationsPendingFieldPlot(a.fieldPlotNumber ?? '-'),
        l10n.registrationsPendingPhone(a.phoneNumber ?? '-'),
      ] else ...[
        l10n.registrationsPendingLegalName(a.legalBusinessName ?? '-'),
        l10n.registrationsPendingBusinessReg(a.businessRegistrationNumber ?? '-'),
        l10n.registrationsPendingBusinessPhone(a.businessPhone ?? '-'),
      ],
    ];
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
                UserAvatar(role: a.role, name: a.fullName, size: 44),
                const SizedBox(width: Gaps.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.fullName, style: textTheme.titleMedium),
                      Text(
                        a.email,
                        style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gaps.sm),
            // The label says "Buyer application" in words, so it doesn't rely on colour.
            Wrap(
              spacing: Gaps.sm,
              runSpacing: Gaps.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusBadge(
                  label: a.isFarmer
                      ? l10n.registrationsPendingFarmerLabel
                      : l10n.registrationsPendingBuyerLabel,
                  tone: a.isFarmer ? BadgeTone.info : BadgeTone.neutral,
                  icon: a.role == Role.buyer
                      ? Icons.storefront_outlined
                      : Icons.agriculture_outlined,
                ),
                Text(
                  l10n.registrationsPendingAppliedOn(format.date(a.createdAt)),
                  style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: Gaps.sm),
            for (final line in details)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  line,
                  style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ),
            const SizedBox(height: Gaps.md),
            if (_rejecting)
              RejectReasonForm(
                prompt: l10n.registrationsPendingRejectPrompt,
                placeholder: l10n.registrationsPendingRejectPlaceholder,
                hint: l10n.registrationsPendingRejectHint,
                submitLabel: l10n.registrationsPendingRejectSubmit,
                cancelLabel: l10n.registrationsPendingCancel,
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
                    child: Text(l10n.registrationsPendingReject),
                  ),
                  FilledButton(
                    key: const Key('approve'),
                    onPressed: _busy ? null : _approve,
                    child: Text(l10n.registrationsPendingApprove),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
