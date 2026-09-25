import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/format/formatters.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/labels.dart';
import '../../../../shared/widgets/crop_icon.dart';
import '../../../issues/data/crop_issue.dart';
import '../../../issues/data/issue_enums.dart';
import '../../../issues/presentation/widgets/issue_badges.dart';

/// One issue in "My Issues": the title, crop, severity, a short description, its status, whether
/// it has a photo, and the date.
class IssueCard extends ConsumerWidget {
  const IssueCard({super.key, required this.issue, required this.onTap});

  final CropIssue issue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final format = ref.watch(formattersProvider);
    final crop = issue.variety.isEmpty
        ? cropLabel(l10n, issue.cropType)
        : '${cropLabel(l10n, issue.cropType)} · ${issue.variety}';
    return Card(
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
                        if (issue.cropType.isNotEmpty)
                          Text(
                            crop,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Gaps.sm),
                  SeverityBadge(issue.severity),
                ],
              ),
              const SizedBox(height: Gaps.sm),
              Text(
                issue.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: Gaps.sm),
              Row(
                children: [
                  // Both sides can shrink: a long Tamil date would otherwise squeeze the badges
                  // into a narrow column, one letter wide.
                  Expanded(
                    flex: 3,
                    child: Wrap(
                      spacing: Gaps.sm,
                      runSpacing: Gaps.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IssueStatusBadge(issue.status),
                        if (issue.advisoryStatus == AdvisoryStatus.preliminary)
                          const AdvisoryStatusBadge(AdvisoryStatus.preliminary),
                        if (issue.hasPhoto)
                          Semantics(
                            label: l10n.issuesMineHasPhoto,
                            child: Icon(
                              Icons.photo_camera_outlined,
                              size: 18,
                              color: colors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Gaps.sm),
                  Expanded(
                    flex: 2,
                    child: Text(
                      format.date(issue.createdAt),
                      textAlign: TextAlign.end,
                      style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
