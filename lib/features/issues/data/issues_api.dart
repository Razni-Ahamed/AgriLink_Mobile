import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/api/paged.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/media/photo_picker.dart';
import 'advisory.dart';
import 'crop_issue.dart';

/// `/api/issues` and `/api/advisories`: reporting crop problems and reading the advice.
///
/// Both the farmer screens and (in Phase 4) the officer screens read issues and advisories, so
/// the models here are the API's full responses.
class IssuesApi {
  IssuesApi(this._api);

  final ApiClient _api;

  /// Reporting an issue with a photo runs the whole analysis (the photo model, a weather lookup,
  /// validation) before the API answers, on top of a possible cold start. That takes 30 to 60
  /// seconds or more, so this call waits longer than the app's default.
  static const Duration submitTimeout = Duration(seconds: 120);

  /// The signed-in farmer's own issues, newest first.
  Future<Paged<CropIssue>> mine({int page = 1, int pageSize = AppConfig.defaultPageSize}) =>
      _api.getPaged('/api/issues/mine', page: page, pageSize: pageSize, item: CropIssue.fromJson);

  /// Reports an issue without a photo.
  Future<CropIssue> create(CreateCropIssueRequest request) => _api.post(
    '/api/issues',
    body: request.toJson(),
    receiveTimeout: submitTimeout,
    decode: _issue,
  );

  /// Reports an issue with one photo, sent as multipart form data. The API takes JPEG, PNG or
  /// WebP up to 5 MB; [PickedPhoto] is always a small JPEG.
  Future<CropIssue> createWithPhoto(CreateCropIssueRequest request, PickedPhoto photo) => _api.post(
    '/api/issues/with-photo',
    body: FormData.fromMap({
      'cropId': request.cropId,
      'title': request.title,
      'description': request.description,
      'severity': request.severity.apiName,
      'photo': MultipartFile.fromBytes(
        photo.bytes,
        filename: photo.fileName,
        contentType: DioMediaType.parse(PickedPhoto.contentType),
      ),
    }),
    receiveTimeout: submitTimeout,
    decode: _issue,
  );

  /// One advisory. For a farmer the API answers 404 while it is still a draft (not yet released),
  /// so a `notFound` [ApiException] here means "not available yet".
  Future<Advisory> advisory(int id) =>
      _api.get('/api/advisories/$id', decode: (data) => Advisory.fromJson(asJson(data)));

  static CropIssue _issue(Object? data) => CropIssue.fromJson(asJson(data));
}

final issuesApiProvider = Provider<IssuesApi>((ref) => IssuesApi(ref.watch(apiClientProvider)));
