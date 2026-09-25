import '../../../core/api/json.dart';
import 'issue_enums.dart';

/// A photo the farmer attached. [url] is an API path (`/api/issues/{id}/images/{id}`) that needs
/// the bearer token, so it can't be shown with a plain `Image.network`.
class IssuePhoto {
  const IssuePhoto({
    required this.imageId,
    required this.url,
    required this.width,
    required this.height,
  });

  factory IssuePhoto.fromJson(Json json) => IssuePhoto(
    imageId: (json['imageId'] as num).toInt(),
    url: field<String>(json, 'url'),
    width: (json['width'] as num?)?.toInt() ?? 0,
    height: (json['height'] as num?)?.toInt() ?? 0,
  );

  final int imageId;
  final String url;
  final int width;
  final int height;
}

/// A disease an officer can correct a photo diagnosis to. Officers and admins only.
class DiseaseOption {
  const DiseaseOption({required this.key, required this.name});

  factory DiseaseOption.fromJson(Json json) =>
      DiseaseOption(key: field<String>(json, 'key'), name: field<String>(json, 'name'));

  final String key;
  final String name;
}

/// What the photo model identified. Only [diseaseKey] and [diseaseName] reach a farmer; the rest
/// is for officers and admins, and is null in a farmer's response.
class PhotoDiagnosis {
  const PhotoDiagnosis({
    required this.diseaseKey,
    required this.diseaseName,
    this.modelConfidence,
    this.modelVersion,
    this.escalationReasons,
    this.suggestedTreatment,
    this.diseaseOptions,
  });

  factory PhotoDiagnosis.fromJson(Json json) => PhotoDiagnosis(
    diseaseKey: field<String>(json, 'diseaseKey'),
    diseaseName: field<String>(json, 'diseaseName'),
    modelConfidence: (json['modelConfidence'] as num?)?.toDouble(),
    modelVersion: json['modelVersion'] as String?,
    escalationReasons: (json['escalationReasons'] as List<Object?>?)?.cast<String>(),
    suggestedTreatment: json['suggestedTreatment'] as String?,
    diseaseOptions: json['diseaseOptions'] == null
        ? null
        : [for (final option in asJsonList(json['diseaseOptions'])) DiseaseOption.fromJson(option)],
  );

  final String diseaseKey;
  final String diseaseName;

  /// The model's calibrated probability for the predicted disease. Officers and admins only.
  final double? modelConfidence;
  final String? modelVersion;

  /// Codes for why the diagnosis was held for an officer. Officers and admins only.
  final List<String>? escalationReasons;

  /// The knowledge base's advice for this disease, a starting point for the officer's own
  /// treatment. Not approved advice. Officers and admins only.
  final String? suggestedTreatment;

  /// What the diagnosis can be corrected to. Officers and admins only.
  final List<DiseaseOption>? diseaseOptions;
}

/// Another issue on the same crop, as context for the officer. Officers and admins only.
class PreviousIssueSummary {
  const PreviousIssueSummary({
    required this.issueId,
    required this.title,
    required this.severity,
    required this.status,
    required this.createdAt,
    this.advisoryId,
  });

  factory PreviousIssueSummary.fromJson(Json json) => PreviousIssueSummary(
    issueId: (json['issueId'] as num).toInt(),
    title: field<String>(json, 'title'),
    severity: IssueSeverity.fromApi(json['severity']),
    status: IssueStatus.fromApi(json['status']),
    createdAt: parseApiDate(field<String>(json, 'createdAt')),
    advisoryId: (json['advisoryId'] as num?)?.toInt(),
  );

  final int issueId;
  final String title;
  final IssueSeverity severity;
  final IssueStatus status;
  final DateTime createdAt;
  final int? advisoryId;
}

/// One step of the AI pipeline that produced an advisory. [input] and [output] are whatever
/// JSON that agent recorded; their shape varies by agent, so callers show them generically.
class AgentStep {
  const AgentStep({
    required this.agentName,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.input,
    this.output,
  });

  factory AgentStep.fromJson(Json json) => AgentStep(
    agentName: field<String>(json, 'agentName'),
    status: json['status'] as String? ?? '',
    startedAt: parseApiDate(field<String>(json, 'startedAt')),
    completedAt: parseApiDateOrNull(json['completedAt']),
    input: json['input'],
    output: json['output'],
  );

  final String agentName;

  /// `Running`, `Completed` or `Failed`.
  final String status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final Object? input;
  final Object? output;
}

/// The AI pipeline's run for an advisory. Officers and admins only.
class AgentTrace {
  const AgentTrace({
    required this.objective,
    required this.status,
    required this.startedAt,
    required this.steps,
    this.completedAt,
  });

  factory AgentTrace.fromJson(Json json) => AgentTrace(
    objective: json['objective'] as String? ?? '',
    status: json['status'] as String? ?? '',
    startedAt: parseApiDate(field<String>(json, 'startedAt')),
    completedAt: parseApiDateOrNull(json['completedAt']),
    steps: [
      for (final step in asJsonList(json['steps'] ?? const <Object?>[])) AgentStep.fromJson(step),
    ],
  );

  final String objective;
  final String status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final List<AgentStep> steps;
}

/// An advisory: the API's `AdvisoryResponse`. It holds the whole response, including what only
/// an officer or admin receives ([previousIssues], [agentTrace] and the diagnosis details), which
/// are null in a farmer's response. The farmer screens and the officer review screens share it.
class Advisory {
  const Advisory({
    required this.id,
    required this.issueId,
    required this.issueTitle,
    required this.status,
    required this.riskLevel,
    required this.recommendation,
    required this.confidenceScore,
    required this.requiresApproval,
    required this.issueDescription,
    required this.issueSeverity,
    required this.issueStatus,
    required this.issueCreatedAt,
    required this.cropType,
    required this.variety,
    required this.district,
    required this.reporterName,
    required this.photos,
    this.reviewedById,
    this.reviewedByName,
    this.reviewedAt,
    this.reviewNote,
    this.previousIssues,
    this.agentTrace,
    this.photoDiagnosis,
    this.confirmedDiseaseKey,
    this.confirmedDiseaseName,
    this.officerTreatment,
  });

  factory Advisory.fromJson(Json json) => Advisory(
    id: (json['advisoryId'] as num).toInt(),
    issueId: (json['issueId'] as num).toInt(),
    issueTitle: json['issueTitle'] as String? ?? '',
    status: AdvisoryStatus.fromApi(json['status']),
    riskLevel: RiskLevel.fromApi(json['riskLevel']),
    recommendation: json['recommendation'] as String? ?? '',
    confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0,
    requiresApproval: json['requiresApproval'] == true,
    reviewedById: (json['reviewedByFK'] as num?)?.toInt(),
    reviewedByName: json['reviewedByName'] as String?,
    reviewedAt: parseApiDateOrNull(json['reviewedAt']),
    reviewNote: json['reviewNote'] as String?,
    issueDescription: json['issueDescription'] as String? ?? '',
    issueSeverity: IssueSeverity.fromApi(json['issueSeverity']),
    issueStatus: IssueStatus.fromApi(json['issueStatus']),
    issueCreatedAt: parseApiDate(field<String>(json, 'issueCreatedAt')),
    cropType: json['cropType'] as String? ?? '',
    variety: json['variety'] as String? ?? '',
    district: json['district'] as String? ?? '',
    reporterName: json['reporterName'] as String? ?? '',
    previousIssues: json['previousIssues'] == null
        ? null
        : [
            for (final issue in asJsonList(json['previousIssues']))
              PreviousIssueSummary.fromJson(issue),
          ],
    agentTrace: json['agentTrace'] == null ? null : AgentTrace.fromJson(asJson(json['agentTrace'])),
    photoDiagnosis: json['photoDiagnosis'] == null
        ? null
        : PhotoDiagnosis.fromJson(asJson(json['photoDiagnosis'])),
    confirmedDiseaseKey: json['confirmedDiseaseKey'] as String?,
    confirmedDiseaseName: json['confirmedDiseaseName'] as String?,
    officerTreatment: json['officerTreatment'] as String?,
    photos: [
      for (final photo in asJsonList(json['photos'] ?? const <Object?>[]))
        IssuePhoto.fromJson(photo),
    ],
  );

  final int id;
  final int issueId;
  final String issueTitle;
  final AdvisoryStatus status;
  final RiskLevel riskLevel;

  /// Written by the AI on the server, in whatever language it produced. Not translated.
  final String recommendation;

  /// 0 to 1. The website shows it as a rounded percentage.
  final double confidenceScore;
  final bool requiresApproval;

  final int? reviewedById;
  final String? reviewedByName;
  final DateTime? reviewedAt;

  /// The reviewing officer's own note.
  final String? reviewNote;

  final String issueDescription;
  final IssueSeverity issueSeverity;
  final IssueStatus issueStatus;
  final DateTime issueCreatedAt;
  final String cropType;
  final String variety;
  final String district;
  final String reporterName;

  /// Other issues on the same crop. Officers and admins only.
  final List<PreviousIssueSummary>? previousIssues;

  /// How the AI reached its recommendation. Officers and admins only.
  final AgentTrace? agentTrace;

  /// What the photo model identified; null when the report had no photo diagnosis.
  final PhotoDiagnosis? photoDiagnosis;

  /// The disease the officer confirmed, or corrected the diagnosis to.
  final String? confirmedDiseaseKey;
  final String? confirmedDiseaseName;

  /// The officer's own treatment. When present it replaces the AI's recommendation.
  final String? officerTreatment;

  final List<IssuePhoto> photos;

  /// The percentage the website shows for [confidenceScore].
  int get confidencePercent => (confidenceScore * 100).round();

  /// The farmer sees the officer's treatment instead of the AI's recommendation when an officer
  /// rejected the advice and wrote their own; showing both would leave them guessing which to
  /// follow. Mirrors the website's `hideAiRecommendation`.
  bool get replacesAiRecommendation =>
      status == AdvisoryStatus.rejected && (officerTreatment?.isNotEmpty ?? false);
}
