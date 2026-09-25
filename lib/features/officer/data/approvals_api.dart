import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/api/paged.dart';
import '../../../core/config/app_config.dart';
import '../../../core/session/role.dart';

/// A farmer or buyer application waiting for a decision (`GET /api/registrations/pending`).
/// Which fields are filled in depends on the [role]: farmers have a plot and phone, buyers have
/// business details.
class PendingRegistration {
  const PendingRegistration({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.district,
    required this.createdAt,
    this.nic,
    this.fieldPlotNumber,
    this.phoneNumber,
    this.businessRegistrationNumber,
    this.businessPhone,
    this.legalBusinessName,
  });

  factory PendingRegistration.fromJson(Json json) => PendingRegistration(
    userId: (json['userId'] as num).toInt(),
    fullName: field<String>(json, 'fullName'),
    email: json['email'] as String? ?? '',
    role: Role.fromApi(json['role'] as String?) ?? Role.farmer,
    district: json['district'] as String? ?? '',
    createdAt: parseApiDate(field<String>(json, 'createdAt')),
    nic: json['nic'] as String?,
    fieldPlotNumber: json['fieldPlotNumber'] as String?,
    phoneNumber: json['phoneNumber'] as String?,
    businessRegistrationNumber: json['businessRegistrationNumber'] as String?,
    businessPhone: json['businessPhone'] as String?,
    legalBusinessName: json['legalBusinessName'] as String?,
  );

  final int userId;
  final String fullName;
  final String email;
  final Role role;
  final String district;
  final DateTime createdAt;
  final String? nic;

  // Farmer only.
  final String? fieldPlotNumber;
  final String? phoneNumber;

  // Buyer only.
  final String? businessRegistrationNumber;
  final String? businessPhone;
  final String? legalBusinessName;

  bool get isFarmer => role == Role.farmer;
}

/// Which detail a [PendingChangeRequest] wants to change. Only these three need approval.
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

/// A request to change a user's full name, NIC or email, waiting for an officer or admin
/// (`GET /api/profile-change-requests/pending`).
class PendingChangeRequest {
  const PendingChangeRequest({
    required this.requestId,
    required this.userId,
    required this.fullName,
    required this.username,
    required this.role,
    required this.changeField,
    required this.oldValue,
    required this.newValue,
    required this.requestedAt,
    this.profilePhotoUrl,
    this.district,
  });

  factory PendingChangeRequest.fromJson(Json json) => PendingChangeRequest(
    requestId: (json['requestId'] as num).toInt(),
    userId: (json['userId'] as num).toInt(),
    fullName: field<String>(json, 'fullName'),
    username: json['username'] as String? ?? '',
    role: Role.fromApi(json['role'] as String?) ?? Role.farmer,
    profilePhotoUrl: json['profilePhotoUrl'] as String?,
    district: json['district'] as String?,
    changeField:
        ChangeRequestField.fromApi(json['field'] as String?) ??
        (throw FormatException('Unknown change request field "${json['field']}"')),
    oldValue: json['oldValue'] as String? ?? '',
    newValue: json['newValue'] as String? ?? '',
    requestedAt: parseApiDate(field<String>(json, 'requestedAt')),
  );

  final int requestId;
  final int userId;
  final String fullName;
  final String username;
  final Role role;
  final String? profilePhotoUrl;

  /// The requester's current district. Empty for an admin, who has none.
  final String? district;

  /// Which detail the requester wants to change.
  final ChangeRequestField changeField;
  final String oldValue;
  final String newValue;
  final DateTime requestedAt;
}

/// The approval queues: new registrations (`/api/registrations`) and identity changes
/// (`/api/profile-change-requests`). An officer only receives farmers from their own district.
class ApprovalsApi {
  ApprovalsApi(this._api);

  final ApiClient _api;

  /// A plain list, not paged, oldest first.
  Future<List<PendingRegistration>> pendingRegistrations() => _api.get(
    '/api/registrations/pending',
    decode: (data) => [for (final item in asJsonList(data)) PendingRegistration.fromJson(item)],
  );

  Future<void> approveRegistration(int userId) =>
      _api.post('/api/registrations/$userId/approve', decode: ApiClient.ignoreBody);

  /// [reason] is shown to the applicant the next time they try to sign in.
  Future<void> rejectRegistration(int userId, String reason) => _api.post(
    '/api/registrations/$userId/reject',
    body: {'reason': reason},
    decode: ApiClient.ignoreBody,
  );

  Future<Paged<PendingChangeRequest>> pendingChangeRequests({
    int page = 1,
    int pageSize = AppConfig.defaultPageSize,
  }) => _api.getPaged(
    '/api/profile-change-requests/pending',
    page: page,
    pageSize: pageSize,
    item: PendingChangeRequest.fromJson,
  );

  /// Approving asks for the approver's own password, like every security action. The password is
  /// only sent, never stored or logged.
  Future<void> approveChangeRequest(int requestId, String currentPassword) => _api.post(
    '/api/profile-change-requests/$requestId/approve',
    body: {'currentPassword': currentPassword},
    decode: ApiClient.ignoreBody,
  );

  Future<void> rejectChangeRequest(int requestId, String reason) => _api.post(
    '/api/profile-change-requests/$requestId/reject',
    body: {'reason': reason},
    decode: ApiClient.ignoreBody,
  );
}

final approvalsApiProvider = Provider<ApprovalsApi>(
  (ref) => ApprovalsApi(ref.watch(apiClientProvider)),
);
