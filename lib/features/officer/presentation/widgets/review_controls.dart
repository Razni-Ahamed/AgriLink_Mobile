import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/dialogs.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../../issues/data/advisory.dart';
import '../../application/review_rules.dart';
import '../../data/review_api.dart';
import 'approval_parts.dart';

/// The officer's decision on an advisory: Approve or Reject, with an optional note. For a photo
/// diagnosis the officer also writes the treatment and can correct the disease, as on the
/// website's `ApproveRejectControls`:
///
/// - **Confirm diagnosis** (approve) needs a treatment when the farmer has had no advice yet.
/// - **Correct diagnosis** (reject) needs the correct disease and a treatment.
///
/// Both ask to confirm first. [onSubmit] sends the decision; if it throws, the controls stay as
/// they are so the officer can try again, and the caller shows why.
class ReviewControls extends StatefulWidget {
  const ReviewControls({super.key, required this.advisory, required this.onSubmit});

  final Advisory advisory;
  final Future<void> Function(ReviewAction action, ReviewAdvisoryRequest request) onSubmit;

  @override
  State<ReviewControls> createState() => _ReviewControlsState();
}

class _ReviewControlsState extends State<ReviewControls> {
  static const _noteMaxLength = 1000;
  static const _treatmentMaxLength = 2000;

  final _note = TextEditingController();
  final _treatment = TextEditingController();

  /// Empty means "no correction chosen" (the dropdown's first entry).
  String _diseaseKey = '';
  ReviewProblems _problems = const ReviewProblems();
  ReviewAction? _sending;

  Advisory get _advisory => widget.advisory;
  PhotoDiagnosis? get _diagnosis => _advisory.photoDiagnosis;

  @override
  void dispose() {
    _note.dispose();
    _treatment.dispose();
    super.dispose();
  }

  Future<void> _submit(ReviewAction action) async {
    final l10n = context.l10n;
    final disease = _diseaseKey.isEmpty ? null : _diseaseKey;
    final problems = checkReview(
      advisory: _advisory,
      action: action,
      treatment: _treatment.text,
      diseaseKey: disease,
    );
    setState(() => _problems = problems);
    if (problems.any) {
      return;
    }
    final photo = _diagnosis != null;
    final approve = action == ReviewAction.approve;
    final confirmed = await showConfirmDialog(
      context,
      title: switch ((approve, photo)) {
        (true, true) => l10n.officerReviewConfirmDiagnosisConfirmTitle,
        (true, false) => l10n.officerReviewApproveConfirmTitle,
        (false, true) => l10n.officerReviewCorrectDiagnosisConfirmTitle,
        (false, false) => l10n.officerReviewRejectConfirmTitle,
      },
      message: l10n.officerReviewConfirmMessage(_advisory.issueTitle),
      confirmLabel: _label(l10n, action),
      destructive: !approve,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _sending = action);
    try {
      await widget.onSubmit(
        action,
        buildReviewRequest(
          advisory: _advisory,
          action: action,
          note: _note.text,
          treatment: _treatment.text,
          diseaseKey: disease,
        ),
      );
    } on Object {
      // The caller has shown what went wrong; the officer keeps what they typed.
    } finally {
      if (mounted) {
        setState(() => _sending = null);
      }
    }
  }

  String _label(AppLocalizations l10n, ReviewAction action) => switch (action) {
    ReviewAction.approve =>
      _diagnosis != null ? l10n.issuesAdvisoryReviewConfirmDiagnosis : l10n.issuesAdvisoryApprove,
    ReviewAction.reject =>
      _diagnosis != null ? l10n.issuesAdvisoryReviewCorrectDiagnosis : l10n.issuesAdvisoryReject,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final diagnosis = _diagnosis;
    final busy = _sending != null;
    final treatmentRequired = treatmentRequiredToConfirm(_advisory);
    final options = diagnosis?.diseaseOptions ?? const <DiseaseOption>[];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gaps.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.officerReviewActionsTitle, style: textTheme.titleMedium),
            ),
            const SizedBox(height: Gaps.md),
            if (diagnosis?.suggestedTreatment != null &&
                diagnosis!.suggestedTreatment!.isNotEmpty) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.tint(colors.forest),
                  border: Border.all(color: colors.forest.withValues(alpha: 0.25)),
                  borderRadius: BorderRadius.circular(kRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Gaps.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.issuesAdvisoryReviewSuggestedTitle,
                        style: textTheme.titleSmall?.copyWith(color: colors.forest),
                      ),
                      Text(
                        l10n.issuesAdvisoryReviewSuggestedHint,
                        style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                      ),
                      const SizedBox(height: Gaps.sm),
                      Text(diagnosis.suggestedTreatment!, style: textTheme.bodyMedium),
                      const SizedBox(height: Gaps.xs),
                      TextButton.icon(
                        key: const Key('review-use-suggested'),
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                _treatment.text = diagnosis.suggestedTreatment!;
                                _problems = ReviewProblems(
                                  needsDisease: _problems.needsDisease,
                                  useCorrectToChange: _problems.useCorrectToChange,
                                );
                              }),
                        icon: const Icon(Icons.subdirectory_arrow_left),
                        label: Text(l10n.issuesAdvisoryReviewUseSuggested),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Gaps.md),
            ],
            if (diagnosis != null) ...[
              AppTextField(
                fieldKey: const Key('review-treatment'),
                controller: _treatment,
                label: treatmentRequired
                    ? l10n.issuesAdvisoryReviewTreatmentLabelRequired
                    : l10n.issuesAdvisoryReviewTreatmentLabelOptional,
                hint: l10n.issuesAdvisoryReviewTreatmentPlaceholder,
                maxLines: 4,
                maxLength: _treatmentMaxLength,
                enabled: !busy,
                textCapitalization: TextCapitalization.sentences,
                serverError: _problems.needsTreatment
                    ? l10n.issuesAdvisoryReviewTreatmentRequired
                    : null,
                onChanged: (_) {
                  if (_problems.needsTreatment) {
                    setState(
                      () => _problems = ReviewProblems(
                        needsDisease: _problems.needsDisease,
                        useCorrectToChange: _problems.useCorrectToChange,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: Gaps.md),
              AppDropdownField<String>(
                key: const Key('review-disease'),
                label: l10n.issuesAdvisoryReviewCorrectDiseaseLabel,
                value: _diseaseKey,
                enabled: !busy,
                items: {
                  '': l10n.issuesAdvisoryReviewCorrectDiseasePlaceholder,
                  for (final option in options) option.key: option.name,
                },
                serverError: _problems.needsDisease
                    ? l10n.issuesAdvisoryReviewDiseaseRequired
                    : _problems.useCorrectToChange
                    ? l10n.issuesAdvisoryReviewUseCorrectToChange
                    : null,
                onChanged: (key) => setState(() {
                  _diseaseKey = key ?? '';
                  _problems = ReviewProblems(needsTreatment: _problems.needsTreatment);
                }),
              ),
              const SizedBox(height: Gaps.md),
            ],
            AppTextField(
              fieldKey: const Key('review-note'),
              controller: _note,
              label: l10n.issuesAdvisoryReviewNoteLabel,
              hint: l10n.issuesAdvisoryReviewNotePlaceholder,
              maxLines: 3,
              maxLength: _noteMaxLength,
              enabled: !busy,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: Gaps.md),
            Wrap(
              spacing: Gaps.sm,
              runSpacing: Gaps.sm,
              children: [
                LoadingButton(
                  key: const Key('review-approve'),
                  label: _label(l10n, ReviewAction.approve),
                  loading: _sending == ReviewAction.approve,
                  onPressed: busy ? null : () => _submit(ReviewAction.approve),
                ),
                RejectButton(
                  key: const Key('review-reject'),
                  label: _label(l10n, ReviewAction.reject),
                  onPressed: busy ? null : () => _submit(ReviewAction.reject),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
