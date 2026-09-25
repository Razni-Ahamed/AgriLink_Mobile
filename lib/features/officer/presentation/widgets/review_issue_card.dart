import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/format/formatters.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/labels.dart';
import '../../../../shared/widgets/crop_icon.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../issues/data/crop_issue.dart';
import '../../../issues/data/issue_enums.dart';
import '../../../issues/presentation/widgets/issue_badges.dart';

/// Which list a card is in, which decides what its bottom line says.
enum ReviewListKind {
  /// Waiting for a decision: "Needs your decision" or "Advice sent — confirm".
  pending,

  /// The officer's own decisions: the outcome and when they made it.
  reviewed,

  /// Every issue (admin): where it stands.
  all,
}

/// One issue in the officer's and admin's lists: the crop, title, severity, who reported it and
/// where, and a bottom line for the list it is in. Opens the advisory when there is one.
class ReviewIssueCard extends ConsumerWidget {
  const ReviewIssueCard({super.key, required this.issue, required this.kind, required this.onTap});

  final CropIssue issue;
  final ReviewListKind kind;

  /// Null when the issue has no advisory to open yet.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final format = ref.watch(formattersProvider);
    final crop = issue.variety.isEmpty
        ? cropLabel(l10n, issue.cropType)
        : '${cropLabel(l10n, issue.cropType)} · ${issue.variety}';
    final reporter = issue.reporterName.isEmpty
        ? l10n.issuesAllUnknownReporter
        : issue.reporterName;
    final reporterLine = [
      l10n.issuesPendingReportedBy(reporter),
      if (issue.district.isNotEmpty) issue.district,
    ].join(' · ');
    final note = issue.reviewNote;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gaps.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.tint(colors.forest),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: 40,
                      child: Center(child: CropIcon(issue.cropType, size: 22)),
                    ),
                  ),
                  const SizedBox(width: Gaps.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          issue.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium,
                        ),
                        Text(
                          l10n.issuesPendingCropAndDate(crop, format.date(issue.createdAt)),
                          style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                        ),
                        Text(
                          reporterLine,
                          style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Gaps.sm),
                  SeverityBadge(issue.severity),
                ],
              ),
              if (kind != ReviewListKind.pending &&
                  issue.description.isNotEmpty &&
                  note == null) ...[
                const SizedBox(height: Gaps.sm),
                Text(
                  issue.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                ),
              ],
              if (kind == ReviewListKind.reviewed && note != null && note.isNotEmpty) ...[
                const SizedBox(height: Gaps.sm),
                Text(
                  note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                ),
              ],
              const SizedBox(height: Gaps.sm),
              Row(
                children: [
                  // Both sides can shrink, so a long Sinhala or Tamil label wraps instead of
                  // squeezing the other side.
                  Expanded(
                    flex: 3,
                    child: Wrap(
                      spacing: Gaps.sm,
                      runSpacing: Gaps.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ..._badges(l10n),
                        if (issue.hasPhoto)
                          Semantics(
                            label: l10n.issuesPendingHasPhoto,
                            child: Icon(
                              Icons.photo_camera_outlined,
                              size: 18,
                              color: colors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (kind == ReviewListKind.reviewed && issue.reviewedAt != null) ...[
                    const SizedBox(width: Gaps.sm),
                    Expanded(
                      flex: 2,
                      child: Text(
                        l10n.issuesReviewedReviewedOn(format.date(issue.reviewedAt!)),
                        textAlign: TextAlign.end,
                        style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _badges(AppLocalizations l10n) => switch (kind) {
    // The API lists cases the farmer has had no advice on first; preliminary advice has
    // already reached them and only needs confirming.
    ReviewListKind.pending => [
      if (issue.advisoryStatus == AdvisoryStatus.preliminary)
        StatusBadge(
          label: l10n.issuesPendingAdviceSent,
          tone: BadgeTone.info,
          icon: Icons.send_outlined,
        )
      else
        StatusBadge(
          label: l10n.issuesPendingNeedsDecision,
          tone: BadgeTone.warning,
          icon: Icons.pending_actions_outlined,
        ),
    ],
    // A reviewed issue is always one of these two outcomes.
    ReviewListKind.reviewed => [
      if (issue.status == IssueStatus.rejected)
        StatusBadge(
          label: l10n.issuesReviewedOutcomeRejected,
          tone: BadgeTone.danger,
          icon: Icons.cancel_outlined,
        )
      else
        StatusBadge(
          label: l10n.issuesReviewedOutcomeResolved,
          tone: BadgeTone.success,
          icon: Icons.check_circle_outline,
        ),
    ],
    ReviewListKind.all => [IssueStatusBadge(issue.status)],
  };
}
