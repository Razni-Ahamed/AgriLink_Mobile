import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../../l10n/labels.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/issue_enums.dart';

// The badge colours follow the website's SeverityBadge, AdvisoryPanel and MyIssuesPage.

/// How serious the farmer says the problem is: Low, Medium or High.
class SeverityBadge extends StatelessWidget {
  const SeverityBadge(this.severity, {super.key});

  final IssueSeverity severity;

  @override
  Widget build(BuildContext context) => StatusBadge(
    label: statusLabel(context.l10n, StatusKind.severity, severity.apiName),
    tone: switch (severity) {
      IssueSeverity.low => BadgeTone.info,
      IssueSeverity.medium => BadgeTone.warning,
      IssueSeverity.high => BadgeTone.danger,
    },
  );
}

/// Where an issue is: Pending, Awaiting review, Resolved or Rejected.
class IssueStatusBadge extends StatelessWidget {
  const IssueStatusBadge(this.status, {super.key});

  final IssueStatus status;

  @override
  Widget build(BuildContext context) => StatusBadge(
    label: statusLabel(context.l10n, StatusKind.issue, status.apiName),
    tone: switch (status) {
      IssueStatus.pending => BadgeTone.info,
      IssueStatus.awaitingReview => BadgeTone.warning,
      IssueStatus.resolved => BadgeTone.success,
      IssueStatus.rejected => BadgeTone.danger,
    },
  );
}

/// The state of an advisory: Draft, Preliminary, Approved or Rejected.
class AdvisoryStatusBadge extends StatelessWidget {
  const AdvisoryStatusBadge(this.status, {super.key});

  final AdvisoryStatus status;

  @override
  Widget build(BuildContext context) => StatusBadge(
    label: statusLabel(context.l10n, StatusKind.advisory, status.apiName),
    tone: switch (status) {
      AdvisoryStatus.draft => BadgeTone.neutral,
      AdvisoryStatus.preliminary => BadgeTone.info,
      AdvisoryStatus.approved => BadgeTone.success,
      AdvisoryStatus.rejected => BadgeTone.danger,
    },
  );
}

/// The AI's risk assessment, worded "Risk: Medium".
class RiskBadge extends StatelessWidget {
  const RiskBadge(this.risk, {super.key});

  final RiskLevel risk;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StatusBadge(
      label: l10n.issuesAdvisoryRiskPrefix(statusLabel(l10n, StatusKind.risk, risk.apiName)),
      tone: switch (risk) {
        RiskLevel.low => BadgeTone.info,
        RiskLevel.medium => BadgeTone.warning,
        RiskLevel.high => BadgeTone.danger,
      },
    );
  }
}
