import '../../../core/api/json.dart';

/// `PUT /api/users/me/profile`. Only the fields that changed are sent; a field left out keeps
/// its value. An empty [displayName] clears it (the full name is shown instead).
class UpdateProfileRequest {
  const UpdateProfileRequest({
    this.displayName,
    this.username,
    this.fieldPlotNumber,
    this.businessName,
  });

  final String? displayName;
  final String? username;

  /// Farmer accounts only.
  final String? fieldPlotNumber;

  /// Buyer accounts only.
  final String? businessName;

  bool get isEmpty =>
      displayName == null && username == null && fieldPlotNumber == null && businessName == null;

  Json toJson() => {
    'displayName': ?displayName,
    'username': ?username,
    'fieldPlotNumber': ?fieldPlotNumber,
    'businessName': ?businessName,
  };
}

/// The details that can only be changed through a request an officer or admin approves
/// (or, for an admin, changed directly). Names match the API.
enum ChangeRequestField {
  fullName('FullName'),
  nic('NIC'),
  email('Email');

  const ChangeRequestField(this.apiName);
  final String apiName;

  static ChangeRequestField? fromApi(String? value) {
    for (final field in values) {
      if (field.apiName == value) {
        return field;
      }
    }
    return null;
  }
}

enum ChangeRequestStatus { pending, approved, rejected, withdrawn, unknown }

/// One of the user's own requests to change a detail.
class ChangeRequest {
  const ChangeRequest({
    required this.requestId,
    required this.field,
    required this.oldValue,
    required this.newValue,
    required this.status,
    required this.requestedAt,
    this.decidedAt,
    this.rejectionReason,
  });

  factory ChangeRequest.fromJson(Json json) => ChangeRequest(
    requestId: (json['requestId'] as num).toInt(),
    field: ChangeRequestField.fromApi(json['field'] as String?),
    oldValue: json['oldValue'] as String? ?? '',
    newValue: json['newValue'] as String? ?? '',
    status: switch (json['status']) {
      'Pending' => ChangeRequestStatus.pending,
      'Approved' => ChangeRequestStatus.approved,
      'Rejected' => ChangeRequestStatus.rejected,
      'Withdrawn' => ChangeRequestStatus.withdrawn,
      _ => ChangeRequestStatus.unknown,
    },
    requestedAt: parseApiDate(json['requestedAt'] as String),
    decidedAt: parseApiDateOrNull(json['decidedAt']),
    rejectionReason: json['rejectionReason'] as String?,
  );

  final int requestId;

  /// Null for a field this version of the app doesn't know.
  final ChangeRequestField? field;
  final String oldValue;
  final String newValue;
  final ChangeRequestStatus status;
  final DateTime requestedAt;
  final DateTime? decidedAt;
  final String? rejectionReason;
}

/// What the signed-in role may change directly or only request, from `GET /api/users/me/security`
/// (the backend's SecurityCapabilities).
enum SecurityCapability { password, phone, fullName, email, nic }

SecurityCapability? _capability(Object? value) => switch (value) {
  'password' => SecurityCapability.password,
  'phone' => SecurityCapability.phone,
  'fullName' => SecurityCapability.fullName,
  'email' => SecurityCapability.email,
  'nic' => SecurityCapability.nic,
  _ => null,
};

class SecuritySettings {
  const SecuritySettings({
    required this.canChange,
    required this.canRequest,
    required this.changeRequests,
    this.phoneNumber,
    this.nic,
  });

  factory SecuritySettings.fromJson(Json json) {
    Set<SecurityCapability> capabilities(Object? list) => {
      for (final item in (list as List?) ?? const []) ?_capability(item),
    };
    return SecuritySettings(
      canChange: capabilities(json['canChange']),
      canRequest: capabilities(json['canRequest']),
      phoneNumber: json['phoneNumber'] as String?,
      nic: json['nic'] as String?,
      changeRequests: [
        for (final item in asJsonList(json['changeRequests'] ?? const [], 'changeRequests'))
          ChangeRequest.fromJson(item),
      ],
    );
  }

  final Set<SecurityCapability> canChange;
  final Set<SecurityCapability> canRequest;
  final String? phoneNumber;
  final String? nic;

  /// Pending requests first, then the most recently decided.
  final List<ChangeRequest> changeRequests;

  ChangeRequest? pendingFor(ChangeRequestField field) {
    for (final request in changeRequests) {
      if (request.field == field && request.status == ChangeRequestStatus.pending) {
        return request;
      }
    }
    return null;
  }

  /// The most recent rejection for [field], to explain why a change didn't happen.
  ChangeRequest? latestRejectionFor(ChangeRequestField field) {
    for (final request in changeRequests) {
      if (request.field == field && request.status == ChangeRequestStatus.rejected) {
        return request;
      }
    }
    return null;
  }
}
