import '../../issues/data/advisory.dart';
import '../../issues/data/issue_enums.dart';
import '../data/review_api.dart';

/// The two decisions an officer can make on an advisory.
enum ReviewAction { approve, reject }

/// What a review is still missing. Mirrors the backend's `AdvisoriesController.Review`, so the
/// officer is told before a request is refused.
class ReviewProblems {
  const ReviewProblems({
    this.needsTreatment = false,
    this.needsDisease = false,
    this.useCorrectToChange = false,
  });

  /// A treatment for the farmer is required.
  final bool needsTreatment;

  /// The correct disease must be chosen to reject a photo diagnosis.
  final bool needsDisease;

  /// A different disease was chosen while approving, which would silently change the diagnosis.
  final bool useCorrectToChange;

  bool get any => needsTreatment || needsDisease || useCorrectToChange;
}

/// Whether the farmer has had no advice yet: a photo diagnosis held back as a draft. Approving
/// it then needs the officer's own treatment, because there is nothing else to send the farmer.
bool treatmentRequiredToConfirm(Advisory advisory) =>
    advisory.photoDiagnosis != null && advisory.status == AdvisoryStatus.draft;

/// Only an advisory still awaiting a decision (a draft, or preliminary advice not yet confirmed)
/// can be reviewed.
bool canReview(Advisory advisory) =>
    advisory.status == AdvisoryStatus.draft || advisory.status == AdvisoryStatus.preliminary;

/// What [action] on [advisory] is missing, given what the officer has typed.
///
/// - No photo diagnosis: nothing is required. The note is optional.
/// - Approve (confirm the diagnosis): a treatment if the farmer has had no advice yet, and no
///   different disease.
/// - Reject (correct the diagnosis): the correct disease and a treatment.
ReviewProblems checkReview({
  required Advisory advisory,
  required ReviewAction action,
  required String treatment,
  required String? diseaseKey,
}) {
  final diagnosis = advisory.photoDiagnosis;
  if (diagnosis == null) {
    return const ReviewProblems();
  }
  final hasTreatment = treatment.trim().isNotEmpty;
  return switch (action) {
    ReviewAction.approve => ReviewProblems(
      useCorrectToChange: diseaseKey != null && diseaseKey != diagnosis.diseaseKey,
      needsTreatment: treatmentRequiredToConfirm(advisory) && !hasTreatment,
    ),
    ReviewAction.reject => ReviewProblems(
      needsDisease: diseaseKey == null,
      needsTreatment: !hasTreatment,
    ),
  };
}

/// The request to send. Blank fields are left out; the disease is only sent when rejecting a
/// photo diagnosis, where it is the correction.
ReviewAdvisoryRequest buildReviewRequest({
  required Advisory advisory,
  required ReviewAction action,
  required String note,
  required String treatment,
  required String? diseaseKey,
}) {
  String? clean(String value) => value.trim().isEmpty ? null : value.trim();
  return ReviewAdvisoryRequest(
    note: clean(note),
    treatment: clean(treatment),
    diseaseKey: action == ReviewAction.reject && advisory.photoDiagnosis != null
        ? diseaseKey
        : null,
  );
}
