import 'dart:convert';
import 'dart:typed_data';

/// JSON the API returns for issues and advisories, for tests.
Map<String, Object?> issueJson({
  int id = 7,
  String severity = 'High',
  String status = 'AwaitingReview',
  int? advisoryId = 21,
  String? advisoryStatus = 'Draft',
  bool hasPhoto = true,
  String title = 'Yellow leaves',
  String description = 'The lower leaves are turning yellow.',
  String createdAt = '2026-09-20T08:30:00',
  String? reviewNote,
}) => {
  'issueId': id,
  'cropId': 3,
  'cropType': 'Green Gram',
  'variety': 'MI 5',
  'district': 'Kandy',
  'reporterName': '',
  'title': title,
  'description': description,
  'severity': severity,
  'status': status,
  'createdAt': createdAt,
  'advisoryId': advisoryId,
  'reviewedAt': null,
  'reviewNote': reviewNote,
  'advisoryStatus': advisoryStatus,
  'hasPhoto': hasPhoto,
};

/// What a farmer receives: none of the officer-only fields.
Map<String, Object?> farmerAdvisoryJson({
  String status = 'Approved',
  Map<String, Object?> extra = const {},
}) => {
  'advisoryId': 21,
  'issueId': 7,
  'issueTitle': 'Yellow leaves',
  'status': status,
  'riskLevel': 'Medium',
  'recommendation': 'Apply a balanced fertiliser.',
  'confidenceScore': 0.874,
  'requiresApproval': false,
  'reviewedByFK': null,
  'reviewedByName': null,
  'reviewedAt': null,
  'reviewNote': null,
  'issueDescription': 'The lower leaves are turning yellow.',
  'issueSeverity': 'High',
  'issueStatus': 'AwaitingReview',
  'issueCreatedAt': '2026-09-20T08:30:00Z',
  'cropType': 'Green Gram',
  'variety': 'MI 5',
  'district': 'Kandy',
  'reporterName': 'Nimal Perera',
  'photoDiagnosis': null,
  'confirmedDiseaseKey': null,
  'confirmedDiseaseName': null,
  'officerTreatment': null,
  'photos': <Object?>[],
  ...extra,
};

/// A 1×1 PNG, so `Image.memory` has something real to decode.
final Uint8List tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
