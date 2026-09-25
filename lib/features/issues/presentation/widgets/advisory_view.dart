import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/format/formatters.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/labels.dart';
import '../../../../shared/widgets/crop_icon.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../data/advisory.dart';
import '../../data/issue_enums.dart';
import 'issue_badges.dart';
import 'issue_photo_gallery.dart';

/// Who is reading the advisory. A farmer sees the advice to act on; a reviewer sees the same and
/// then, around it, the tools to decide (which Phase 4 adds).
enum AdvisoryAudience { farmer, reviewer }

/// The read-only body of an advisory: what was reported, the photos, the status, risk and
/// confidence, the diagnosis, the advice, and who reviewed it with their note. It has no
/// farmer-only or officer-only assumptions beyond [audience], so the officer's review screen
/// puts its approve and reject controls around this.
///
/// It mirrors the website's `AdvisoryPanel`.
class AdvisoryView extends ConsumerWidget {
  const AdvisoryView({
    super.key,
    required this.advisory,
    this.audience = AdvisoryAudience.reviewer,
  });

  final Advisory advisory;
  final AdvisoryAudience audience;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final format = ref.watch(formattersProvider);
    final isFarmer = audience == AdvisoryAudience.farmer;

    // The officer's own diagnosis wins over what the photo model guessed.
    final diagnosis = advisory.confirmedDiseaseName != null
        ? l10n.issuesAdvisoryConfirmedDiagnosis(advisory.confirmedDiseaseName!)
        : advisory.photoDiagnosis != null
        ? l10n.issuesAdvisoryPhotoDiagnosis(advisory.photoDiagnosis!.diseaseName)
        : null;
    // A farmer whose officer rejected the AI's advice and wrote their own is shown only the
    // officer's, so they aren't left guessing which to follow.
    final showRecommendation = !(isFarmer && advisory.replacesAiRecommendation);
    final treatment = advisory.officerTreatment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isFarmer && advisory.status == AdvisoryStatus.preliminary) ...[
          InfoBanner(
            title: l10n.issuesAdvisoryPreliminaryTitle,
            message: l10n.issuesAdvisoryPreliminaryBody,
          ),
          const SizedBox(height: Gaps.md),
        ],
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.tint(colors.textSecondary),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Gaps.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CropIcon(advisory.cropType, size: 18),
                    const SizedBox(width: Gaps.sm),
                    Expanded(
                      child: Text(
                        advisory.variety.isEmpty
                            ? cropLabel(l10n, advisory.cropType)
                            : '${cropLabel(l10n, advisory.cropType)} · ${advisory.variety}',
                        style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: Gaps.sm),
                    SeverityBadge(advisory.issueSeverity),
                  ],
                ),
                const SizedBox(height: Gaps.sm),
                Text(advisory.issueDescription, style: textTheme.bodyMedium),
                const SizedBox(height: Gaps.sm),
                Text(
                  l10n.issuesAdvisoryReportedBy(
                    advisory.reporterName.isEmpty
                        ? l10n.issuesAdvisoryUnknownReporter
                        : advisory.reporterName,
                    advisory.district,
                    format.date(advisory.issueCreatedAt),
                  ),
                  style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        if (advisory.photos.isNotEmpty) ...[
          const SizedBox(height: Gaps.md),
          IssuePhotoGallery(photos: advisory.photos),
        ],
        const SizedBox(height: Gaps.md),
        Wrap(
          spacing: Gaps.sm,
          runSpacing: Gaps.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AdvisoryStatusBadge(advisory.status),
            RiskBadge(advisory.riskLevel),
            Text(
              l10n.issuesAdvisoryConfidence(advisory.confidencePercent),
              style: textTheme.bodyMedium?.mono.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
        if (diagnosis != null) ...[
          const SizedBox(height: Gaps.md),
          Text(diagnosis, style: textTheme.titleSmall),
        ],
        if (treatment != null && treatment.isNotEmpty) ...[
          const SizedBox(height: Gaps.md),
          _Callout(title: l10n.issuesAdvisoryOfficerAdvice, body: treatment, color: colors.forest),
        ],
        if (showRecommendation) ...[
          const SizedBox(height: Gaps.md),
          Semantics(
            header: true,
            child: Text(
              l10n.issuesAdvisoryRecommendation,
              style: textTheme.titleSmall?.copyWith(color: colors.textSecondary),
            ),
          ),
          const SizedBox(height: Gaps.xs),
          // Written by the AI on the server, so it stays in whatever language it came in.
          Text(advisory.recommendation, style: textTheme.bodyLarge),
        ],
        if (advisory.reviewedByName != null && advisory.reviewedAt != null) ...[
          const SizedBox(height: Gaps.md),
          Text(
            l10n.issuesAdvisoryReviewedBy(
              advisory.reviewedByName!,
              format.date(advisory.reviewedAt!),
            ),
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          if (advisory.reviewNote != null && advisory.reviewNote!.isNotEmpty) ...[
            const SizedBox(height: Gaps.sm),
            _Callout(
              title: l10n.issuesAdvisoryOfficerNote,
              body: advisory.reviewNote!,
              color: colors.textSecondary,
            ),
          ],
        ],
      ],
    );
  }
}

/// A titled box for the officer's words.
class _Callout extends StatelessWidget {
  const _Callout({required this.title, required this.body, required this.color});

  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.tint(color),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Gaps.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: textTheme.titleSmall?.copyWith(color: color)),
            ),
            const SizedBox(height: Gaps.xs),
            Text(body, style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
