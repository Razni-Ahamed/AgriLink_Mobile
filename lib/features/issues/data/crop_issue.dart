import '../../../core/api/json.dart';
import 'issue_enums.dart';

/// A reported crop problem: the API's `CropIssueResponse`.
///
/// Shared by the farmer's "My Issues" and the officer and admin lists. [reporterName] is only
/// filled in on the officer and admin lists; the farmer's own list leaves it empty.
class CropIssue {
  const CropIssue({
    required this.id,
    required this.cropId,
    required this.cropType,
    required this.variety,
    required this.district,
    required this.reporterName,
    required this.title,
    required this.description,
    required this.severity,
    required this.status,
    required this.createdAt,
    required this.hasPhoto,
    this.advisoryId,
    this.reviewedAt,
    this.reviewNote,
    this.advisoryStatus,
  });

  factory CropIssue.fromJson(Json json) => CropIssue(
    id: (json['issueId'] as num).toInt(),
    cropId: (json['cropId'] as num).toInt(),
    cropType: json['cropType'] as String? ?? '',
    variety: json['variety'] as String? ?? '',
    district: json['district'] as String? ?? '',
    reporterName: json['reporterName'] as String? ?? '',
    title: field<String>(json, 'title'),
    description: json['description'] as String? ?? '',
    severity: IssueSeverity.fromApi(json['severity']),
    status: IssueStatus.fromApi(json['status']),
    createdAt: parseApiDate(field<String>(json, 'createdAt')),
    hasPhoto: json['hasPhoto'] == true,
    advisoryId: (json['advisoryId'] as num?)?.toInt(),
    reviewedAt: parseApiDateOrNull(json['reviewedAt']),
    reviewNote: json['reviewNote'] as String?,
    advisoryStatus: json['advisoryStatus'] == null
        ? null
        : AdvisoryStatus.fromApi(json['advisoryStatus']),
  );

  final int id;
  final int cropId;
  final String cropType;
  final String variety;
  final String district;
  final String reporterName;
  final String title;
  final String description;
  final IssueSeverity severity;
  final IssueStatus status;
  final DateTime createdAt;

  /// Whether the farmer attached a photo.
  final bool hasPhoto;

  /// The latest advisory for this issue; null until one exists.
  final int? advisoryId;

  /// When that advisory was reviewed; null while it is still waiting for an officer.
  final DateTime? reviewedAt;

  /// The reviewing officer's own note, if they left one.
  final String? reviewNote;
  final AdvisoryStatus? advisoryStatus;

  /// Whether the farmer can open the advisory: one exists and it has been released. A draft
  /// isn't visible to farmers (the API answers 404).
  bool get hasReleasedAdvisory => advisoryId != null && (advisoryStatus?.isReleased ?? false);
}

/// The body for reporting an issue: `POST /api/issues`. For a photo it is sent as form fields
/// instead (see `IssuesApi.createWithPhoto`).
class CreateCropIssueRequest {
  const CreateCropIssueRequest({
    required this.cropId,
    required this.title,
    required this.description,
    required this.severity,
  });

  final int cropId;
  final String title;
  final String description;
  final IssueSeverity severity;

  Json toJson() => {
    'cropId': cropId,
    'title': title,
    'description': description,
    'severity': severity.apiName,
  };
}
