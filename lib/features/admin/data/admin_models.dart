import '../../../core/api/json.dart';
import '../../../core/session/role.dart';

/// The platform-wide numbers on the admin dashboard (`GET /api/admin/metrics`).
class AdminMetrics {
  const AdminMetrics({
    required this.totalUsers,
    required this.totalFarms,
    required this.totalCrops,
    required this.issuesReported,
    required this.issuesPending,
    required this.issuesResolved,
    required this.harvestVolumeSoldThisMonth,
  });

  factory AdminMetrics.fromJson(Json json) => AdminMetrics(
    totalUsers: (json['totalUsers'] as num? ?? 0).toInt(),
    totalFarms: (json['totalFarms'] as num? ?? 0).toInt(),
    totalCrops: (json['totalCrops'] as num? ?? 0).toInt(),
    issuesReported: (json['issuesReported'] as num? ?? 0).toInt(),
    issuesPending: (json['issuesPending'] as num? ?? 0).toInt(),
    issuesResolved: (json['issuesResolved'] as num? ?? 0).toInt(),
    harvestVolumeSoldThisMonth: (json['harvestVolumeSoldThisMonth'] as num? ?? 0).toDouble(),
  );

  final int totalUsers;
  final int totalFarms;
  final int totalCrops;
  final int issuesReported;
  final int issuesPending;
  final int issuesResolved;

  /// In kilograms.
  final double harvestVolumeSoldThisMonth;
}

/// One row of `GET /api/admin/users`. Only what the list shows: the phone, NIC and business
/// details of a user are not in it.
class AdminUser {
  const AdminUser({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.username,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.profilePhotoUrl,
    this.district,
    this.department,
  });

  factory AdminUser.fromJson(Json json) => AdminUser(
    userId: (json['userId'] as num).toInt(),
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    username: json['username'] as String? ?? '',
    profilePhotoUrl: json['profilePhotoUrl'] as String?,
    role: Role.fromApi(json['role'] as String?) ?? Role.farmer,
    district: json['district'] as String?,
    department: json['department'] as String?,
    isActive: json['isActive'] == true,
    createdAt: parseApiDate(field<String>(json, 'createdAt')),
  );

  final int userId;
  final String fullName;
  final String email;
  final String username;
  final String? profilePhotoUrl;
  final Role role;
  final String? district;

  /// Only officers have one.
  final String? department;
  final bool isActive;
  final DateTime createdAt;

  bool get isAdmin => role == Role.admin;

  /// Only officer and buyer accounts can be re-typed here; farmers and admins can't.
  bool get canChangeRole => role == Role.officer || role == Role.buyer;
}

/// `POST /api/admin/users`. A department is required for an officer, a business name for a buyer.
class CreateUserRequest {
  const CreateUserRequest({
    required this.fullName,
    required this.email,
    required this.password,
    required this.role,
    required this.district,
    this.username,
    this.departmentId,
    this.businessName,
  });

  final String fullName;
  final String email;

  /// Sent to the server and nowhere else. It is never logged or kept.
  final String password;
  final Role role;
  final String district;

  /// Left out to let the server make one from the full name.
  final String? username;
  final int? departmentId;
  final String? businessName;

  Json toJson() => {
    'fullName': fullName,
    'email': email,
    if (username != null && username!.isNotEmpty) 'username': username,
    'password': password,
    'role': role.apiName,
    'district': district,
    if (role == Role.officer && departmentId != null) 'departmentId': departmentId,
    if (role == Role.buyer && businessName != null) 'businessName': businessName,
  };
}

/// The account `POST /api/admin/users` made.
class CreatedUser {
  const CreatedUser({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.username,
    required this.role,
  });

  factory CreatedUser.fromJson(Json json) => CreatedUser(
    userId: (json['userId'] as num).toInt(),
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    username: json['username'] as String? ?? '',
    role: Role.fromApi(json['role'] as String?) ?? Role.officer,
  );

  final int userId;
  final String fullName;
  final String email;
  final String username;
  final Role role;
}

/// `PUT /api/admin/users/{id}/role`, for officer and buyer accounts only.
class ChangeRoleRequest {
  const ChangeRoleRequest({
    required this.role,
    required this.district,
    this.departmentId,
    this.businessName,
  });

  final Role role;
  final String district;
  final int? departmentId;
  final String? businessName;

  Json toJson() => {
    'role': role.apiName,
    'district': district,
    if (role == Role.officer && departmentId != null) 'departmentId': departmentId,
    if (role == Role.buyer && businessName != null) 'businessName': businessName,
  };
}

/// `PUT /api/admin/users/{id}/profile`. A field left out (null) is left alone by the server; the
/// app never sends an empty string to clear one.
class UpdateUserProfileRequest {
  const UpdateUserProfileRequest({
    this.fullName,
    this.displayName,
    this.email,
    this.phoneNumber,
    this.nic,
    this.district,
    this.businessRegistrationNumber,
    this.businessName,
    this.fieldPlotNumber,
  });

  final String? fullName;
  final String? displayName;
  final String? email;
  final String? phoneNumber;
  final String? nic;
  final String? district;
  final String? businessRegistrationNumber;
  final String? businessName;
  final String? fieldPlotNumber;

  /// Nothing to change, so nothing to send.
  bool get isEmpty => toJson().isEmpty;

  Json toJson() => {
    if (fullName != null) 'fullName': fullName,
    if (displayName != null) 'displayName': displayName,
    if (email != null) 'email': email,
    if (phoneNumber != null) 'phoneNumber': phoneNumber,
    if (nic != null) 'nic': nic,
    if (district != null) 'district': district,
    if (businessRegistrationNumber != null)
      'businessRegistrationNumber': businessRegistrationNumber,
    if (businessName != null) 'businessName': businessName,
    if (fieldPlotNumber != null) 'fieldPlotNumber': fieldPlotNumber,
  };
}

/// A department officers belong to.
class Department {
  const Department({required this.departmentId, required this.name, required this.createdAt});

  factory Department.fromJson(Json json) => Department(
    departmentId: (json['departmentId'] as num).toInt(),
    name: field<String>(json, 'name'),
    createdAt: parseApiDate(field<String>(json, 'createdAt')),
  );

  final int departmentId;
  final String name;
  final DateTime createdAt;
}

/// One line of the audit log (`GET /api/admin/audit-logs`): who did what to which record.
class AuditLogEntry {
  const AuditLogEntry({
    required this.auditId,
    required this.userId,
    required this.userName,
    required this.action,
    required this.entityName,
    required this.entityId,
    required this.createdAt,
    this.oldValue,
    this.newValue,
  });

  factory AuditLogEntry.fromJson(Json json) => AuditLogEntry(
    auditId: (json['auditId'] as num).toInt(),
    userId: (json['userId'] as num).toInt(),
    userName: json['userName'] as String? ?? '',
    action: json['action'] as String? ?? '',
    entityName: json['entityName'] as String? ?? '',
    entityId: (json['entityId'] as num).toInt(),
    oldValue: json['oldValue'] as String?,
    newValue: json['newValue'] as String?,
    createdAt: parseApiDate(field<String>(json, 'createdAt')),
  );

  final int auditId;
  final int userId;
  final String userName;
  final String action;
  final String entityName;
  final int entityId;
  final String? oldValue;
  final String? newValue;
  final DateTime createdAt;

  bool get hasValues => (oldValue ?? '').isNotEmpty || (newValue ?? '').isNotEmpty;
}
