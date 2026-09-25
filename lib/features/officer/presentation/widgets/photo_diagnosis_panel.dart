import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../issues/data/advisory.dart';
import '../../../issues/data/issue_enums.dart';

/// What the photo model said and why it is waiting for this officer. Only officers and admins
/// receive the confidence, model version and reasons, so it is shown around the advisory the
/// farmer would also see. Shows nothing when the report had no photo diagnosis.
///
/// Mirrors the website's `PhotoDiagnosisReviewPanel`.
class PhotoDiagnosisPanel extends StatelessWidget {
  const PhotoDiagnosisPanel({super.key, required this.advisory});

  final Advisory advisory;

  @override
  Widget build(BuildContext context) {
    final diagnosis = advisory.photoDiagnosis;
    if (diagnosis == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final reasons = diagnosis.escalationReasons ?? const <String>[];
    final confidence = diagnosis.modelConfidence;
    final version = diagnosis.modelVersion;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.canvas,
        border: Border.all(color: colors.forest.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Gaps.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_camera_outlined, size: 20, color: colors.forest),
                const SizedBox(width: Gaps.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(l10n.issuesPhotoReviewTitle, style: textTheme.titleSmall),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gaps.sm),
            Text(
              l10n.issuesPhotoReviewDisease(diagnosis.diseaseName),
              style: textTheme.titleMedium,
            ),
            if (confidence != null)
              Text(
                l10n.issuesPhotoReviewModelConfidence((confidence * 100).round()),
                style: textTheme.bodyMedium?.mono.copyWith(color: colors.textSecondary),
              ),
            if (version != null && version.isNotEmpty)
              Text(
                l10n.issuesPhotoReviewModelVersion(version),
                style: textTheme.bodySmall?.mono.copyWith(color: colors.textSecondary),
              ),
            if (advisory.status == AdvisoryStatus.preliminary) ...[
              const SizedBox(height: Gaps.sm),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.tint(colors.info),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Gaps.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 18, color: colors.info),
                      const SizedBox(width: Gaps.sm),
                      Expanded(
                        child: Text(
                          l10n.issuesPhotoReviewAdviceAlreadySent,
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (reasons.isNotEmpty) ...[
              const SizedBox(height: Gaps.sm),
              Text(
                l10n.issuesPhotoReviewReasonsTitle,
                style: textTheme.labelMedium?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: Gaps.xs),
              for (final code in reasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gaps.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: textTheme.bodyMedium),
                      Expanded(child: Text(escalationReasonLabel(l10n, code))),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Why a diagnosis was held for an officer. A code the app doesn't know is shown as it is.
String escalationReasonLabel(AppLocalizations l10n, String code) => switch (code) {
  'UnknownDisease' => l10n.issuesPhotoReviewReasonsUnknownDisease,
  'SeriousDisease' => l10n.issuesPhotoReviewReasonsSeriousDisease,
  'NoApprovedTreatment' => l10n.issuesPhotoReviewReasonsNoApprovedTreatment,
  'ModelNeverAutoReleases' => l10n.issuesPhotoReviewReasonsModelNeverAutoReleases,
  'LowConfidence' => l10n.issuesPhotoReviewReasonsLowConfidence,
  'DescriptionMismatch' => l10n.issuesPhotoReviewReasonsDescriptionMismatch,
  'AutoReleaseDisabled' => l10n.issuesPhotoReviewReasonsAutoReleaseDisabled,
  'TriageFailed' => l10n.issuesPhotoReviewReasonsTriageFailed,
  _ => code,
};
