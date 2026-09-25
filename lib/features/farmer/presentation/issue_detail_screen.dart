import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/api/api_error_parser.dart';
import '../../../core/format/formatters.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/labels.dart';
import '../../../shared/widgets/crop_icon.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/state_views.dart';
import '../../issues/application/advisories.dart';
import '../../issues/data/crop_issue.dart';
import '../../issues/data/issue_enums.dart';
import '../../issues/presentation/widgets/issue_badges.dart';
import '../../issues/presentation/widgets/issue_photo_gallery.dart';
import '../application/my_issues.dart';
import '../farmer_paths.dart';

/// One reported issue: what was reported, where it stands, the officer's note, and a button to
/// the advice once there is some. The API has no "issue by id", so the list passes the issue
/// along ([initial]); it is then refreshed in the background, and looked up if the page was
/// opened without one.
class IssueDetailScreen extends ConsumerWidget {
  const IssueDetailScreen({super.key, required this.issueId, this.initial});

  final int issueId;
  final CropIssue? initial;

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    try {
      ref.invalidate(myIssueProvider(issueId));
      await ref.read(myIssueProvider(issueId).future);
    } on Object catch (error) {
      if (context.mounted) {
        showToast(context, describeError(error, context.l10n), tone: ToastTone.error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final loaded = ref.watch(myIssueProvider(issueId));
    // The issue from the list shows straight away; a newer copy replaces it when it arrives.
    final issue = loaded.value ?? initial;
    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.issuesDetailTitle),
      body: issue != null
          ? RefreshIndicator(
              onRefresh: () => _refresh(context, ref),
              child: _IssueContent(issue: issue),
            )
          : loaded.hasError
          ? ErrorView(error: loaded.error!, onRetry: () => ref.invalidate(myIssueProvider(issueId)))
          : loaded.isLoading
          ? const LoadingView()
          : EmptyView(icon: Icons.search_off_outlined, title: l10n.issuesDetailNotFound),
    );
  }
}

class _IssueContent extends ConsumerWidget {
  const _IssueContent({required this.issue});

  final CropIssue issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final format = ref.watch(formattersProvider);
    final hasAdvice = issue.hasReleasedAdvisory;
    // The photo's address only comes with the advisory, so it can be shown once there is one.
    final advisory = hasAdvice ? ref.watch(advisoryProvider(issue.advisoryId!)).value : null;
    final crop = issue.variety.isEmpty
        ? cropLabel(l10n, issue.cropType)
        : '${cropLabel(l10n, issue.cropType)} · ${issue.variety}';
    final note = issue.reviewNote;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Gaps.md),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: colors.tint(colors.forest), shape: BoxShape.circle),
              child: SizedBox.square(
                dimension: 48,
                child: Center(child: CropIcon(issue.cropType, size: 28)),
              ),
            ),
            const SizedBox(width: Gaps.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(issue.title, style: textTheme.headlineSmall),
                  if (issue.cropType.isNotEmpty)
                    Text(crop, style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Gaps.md),
        Wrap(
          spacing: Gaps.sm,
          runSpacing: Gaps.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SeverityBadge(issue.severity),
            IssueStatusBadge(issue.status),
            if (issue.advisoryStatus == AdvisoryStatus.preliminary)
              const AdvisoryStatusBadge(AdvisoryStatus.preliminary),
          ],
        ),
        const SizedBox(height: Gaps.sm),
        Text(
          l10n.issuesDetailReportedOn(format.date(issue.createdAt)),
          style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: Gaps.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gaps.md),
            child: Text(issue.description, style: textTheme.bodyLarge),
          ),
        ),
        if (advisory != null && advisory.photos.isNotEmpty) ...[
          const SizedBox(height: Gaps.md),
          IssuePhotoGallery(photos: advisory.photos),
        ] else if (issue.hasPhoto) ...[
          const SizedBox(height: Gaps.md),
          Row(
            children: [
              Icon(Icons.photo_camera_outlined, size: 18, color: colors.textSecondary),
              const SizedBox(width: Gaps.sm),
              Text(
                l10n.issuesMineHasPhoto,
                style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ],
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: Gaps.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gaps.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(l10n.issuesAdvisoryOfficerNote, style: textTheme.titleSmall),
                  ),
                  const SizedBox(height: Gaps.xs),
                  Text(note, style: textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: Gaps.lg),
        if (hasAdvice)
          FilledButton.icon(
            key: const Key('view-advisory'),
            onPressed: () => context.push(FarmerPaths.advisory(issue.advisoryId!)),
            icon: const Icon(Icons.medical_information_outlined),
            label: Text(l10n.issuesDetailViewAdvisory),
          )
        else
          InfoBanner(message: l10n.issuesDetailBeingReviewed),
      ],
    );
  }
}
