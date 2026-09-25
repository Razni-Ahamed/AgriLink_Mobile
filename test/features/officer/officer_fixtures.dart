import 'package:agrilink_mobile/features/issues/data/advisory.dart';

import '../issues/issue_fixtures.dart';

/// What the photo model said, as an officer receives it.
Map<String, Object?> photoDiagnosisJson({
  List<String> reasons = const ['SeriousDisease'],
  String? suggestedTreatment = 'Spray a copper fungicide every 7 days.',
}) => {
  'diseaseKey': 'leaf_spot',
  'diseaseName': 'Leaf spot',
  'modelConfidence': 0.914,
  'modelVersion': 'v2.1',
  'escalationReasons': reasons,
  'suggestedTreatment': suggestedTreatment,
  'diseaseOptions': [
    {'key': 'leaf_spot', 'name': 'Leaf spot'},
    {'key': 'rust', 'name': 'Rust'},
    {'key': 'other', 'name': 'Other'},
  ],
};

/// How the AI reached the advice, with a step of each kind.
Map<String, Object?> agentTraceJson() => {
  'objective': 'Advise on yellow leaves',
  'status': 'Completed',
  'startedAt': '2026-09-20T08:30:00Z',
  'completedAt': '2026-09-20T08:30:04Z',
  'steps': [
    {
      'agentName': 'PlannerAgent',
      'status': 'Completed',
      'startedAt': '2026-09-20T08:30:00Z',
      'completedAt': '2026-09-20T08:30:00.350Z',
      'input': {'cropType': 'Green Gram', 'district': 'Kandy'},
      'output': {
        'agentsToRun': ['CropAnalysisAgent', 'WeatherAgent'],
        'useCropAgent': true,
        'score': 0.5,
        'steps': 3,
      },
    },
    {
      'agentName': 'WeatherAgent',
      'status': 'Failed',
      'startedAt': '2026-09-20T08:30:01Z',
      'completedAt': '2026-09-20T08:30:03.400Z',
      'input': null,
      'output': null,
    },
  ],
};

Map<String, Object?> previousIssueJson({int id = 3, String title = 'Aphids on leaves'}) => {
  'issueId': id,
  'title': title,
  'severity': 'Medium',
  'status': 'Resolved',
  'createdAt': '2026-08-01T08:30:00Z',
  'advisoryId': 18,
};

/// An advisory as an officer or admin receives it.
Advisory reviewerAdvisory({
  String status = 'Draft',
  bool photo = false,
  Map<String, Object?> diagnosis = const {},
  bool withTrace = true,
  List<Map<String, Object?>> previous = const [],
}) => Advisory.fromJson(
  farmerAdvisoryJson(
    status: status,
    extra: {
      'requiresApproval': true,
      'previousIssues': previous,
      'agentTrace': withTrace ? agentTraceJson() : null,
      'photoDiagnosis': photo ? {...photoDiagnosisJson(), ...diagnosis} : null,
    },
  ),
);
