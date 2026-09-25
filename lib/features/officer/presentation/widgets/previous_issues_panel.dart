import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/format/formatters.dart';
import '../../../../l10n/l10n.dart';
import '../../../issues/data/advisory.dart';
import '../../../issues/presentation/widgets/issue_badges.dart';

/// Other issues reported on the same crop, so an officer can tell a recurring problem from a
/// first one. Each that has an advisory opens it through [onOpen]. Mirrors the website's
/// `PreviousIssuesList`.
class PreviousIssuesPanel extends ConsumerWidget {
  const PreviousIssuesPanel({super.key, required this.issues, required this.onOpen});

  final List<PreviousIssueSummary> issues;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final format = ref.watch(formattersProvider);
    // A Material, not a coloured box, so the rows' ink shows.
    return Material(
      color: colors.canvas,
      borderRadius: BorderRadius.circular(kRadius),
      child: Padding(
        padding: const EdgeInsets.all(Gaps.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, size: 20, color: colors.textSecondary),
                const SizedBox(width: Gaps.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      issues.isEmpty
                          ? l10n.issuesPreviousIssuesEmpty
                          : l10n.issuesPreviousIssuesTitle(issues.length),
                      style: textTheme.titleSmall,
                    ),
                  ),
                ),
              ],
            ),
            for (final issue in issues) ...[
              const SizedBox(height: Gaps.sm),
              InkWell(
                key: Key('previous-${issue.issueId}'),
                borderRadius: BorderRadius.circular(12),
                onTap: issue.advisoryId == null ? null : () => onOpen(issue.advisoryId!),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gaps.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(issue.title, style: textTheme.bodyMedium),
                            Text(
                              format.date(issue.createdAt),
                              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Gaps.sm),
                      Wrap(
                        spacing: Gaps.xs,
                        runSpacing: Gaps.xs,
                        alignment: WrapAlignment.end,
                        children: [SeverityBadge(issue.severity), IssueStatusBadge(issue.status)],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
