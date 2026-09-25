import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/api/paged.dart';
import '../../../core/config/app_config.dart';
import '../../issues/data/advisory.dart';
import '../../issues/data/crop_issue.dart';

/// The body of an approve or reject (`ReviewAdvisoryRequest`). Every field is optional on the
/// wire; which ones a review needs depends on the advisory (see `checkReview`).
class ReviewAdvisoryRequest {
  const ReviewAdvisoryRequest({this.note, this.treatment, this.diseaseKey});

  /// The officer's own words, kept on the advisory and sent to the farmer with the decision.
  final String? note;

  /// What the farmer should do, for a photo diagnosis.
  final String? treatment;

  /// The correct disease, when rejecting a photo diagnosis.
  final String? diseaseKey;

  Json toJson() => {
    if (note != null) 'note': note,
    if (treatment != null) 'treatment': treatment,
    if (diseaseKey != null) 'diseaseKey': diseaseKey,
  };
}

/// The officer and admin side of issues and advisories: the lists of issues to review, and the
/// decision itself.
///
/// The models (`CropIssue`, `Advisory`) are Phase 2's; only the calls that need an officer's
/// or admin's role are here.
class ReviewApi {
  ReviewApi(this._api);

  final ApiClient _api;

  /// Issues waiting for a decision. An officer only receives their own district's.
  Future<Paged<CropIssue>> pending({int page = 1, int pageSize = AppConfig.defaultPageSize}) => _api
      .getPaged('/api/issues/pending', page: page, pageSize: pageSize, item: CropIssue.fromJson);

  /// Issues this officer has decided, most recent first. Officers only.
  Future<Paged<CropIssue>> reviewed({int page = 1, int pageSize = AppConfig.defaultPageSize}) =>
      _api.getPaged(
        '/api/issues/reviewed',
        page: page,
        pageSize: pageSize,
        item: CropIssue.fromJson,
      );

  /// Every issue, whatever its status. Admins only.
  Future<Paged<CropIssue>> all({int page = 1, int pageSize = AppConfig.defaultPageSize}) =>
      _api.getPaged('/api/issues', page: page, pageSize: pageSize, item: CropIssue.fromJson);

  /// Approves an advisory awaiting review. Answers 400 "Only advisories awaiting review can be
  /// reviewed." when someone got there first.
  Future<Advisory> approve(int advisoryId, ReviewAdvisoryRequest request) => _api.post(
    '/api/advisories/$advisoryId/approve',
    body: request.toJson(),
    decode: (data) => Advisory.fromJson(asJson(data)),
  );

  Future<Advisory> reject(int advisoryId, ReviewAdvisoryRequest request) => _api.post(
    '/api/advisories/$advisoryId/reject',
    body: request.toJson(),
    decode: (data) => Advisory.fromJson(asJson(data)),
  );
}

final reviewApiProvider = Provider<ReviewApi>((ref) => ReviewApi(ref.watch(apiClientProvider)));
