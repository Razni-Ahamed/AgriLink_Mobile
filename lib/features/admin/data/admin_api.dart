import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/api/paged.dart';
import '../../../core/config/app_config.dart';
import 'admin_models.dart';

/// `/api/admin` and `/api/admin/departments`: admin only.
///
/// These change real accounts, so nothing here retries or repeats a call by itself.
class AdminApi {
  AdminApi(this._api);

  final ApiClient _api;

  Future<AdminMetrics> metrics() =>
      _api.get('/api/admin/metrics', decode: (data) => AdminMetrics.fromJson(asJson(data)));

  /// Every user, not paged. The screen searches and filters them on the device.
  Future<List<AdminUser>> users() => _api.get(
    '/api/admin/users',
    decode: (data) => [for (final item in asJsonList(data)) AdminUser.fromJson(item)],
  );

  Future<CreatedUser> createUser(CreateUserRequest request) => _api.post(
    '/api/admin/users',
    body: request.toJson(),
    decode: (data) => CreatedUser.fromJson(asJson(data)),
  );

  /// The user as it is after the change.
  Future<AdminUser> changeRole(int userId, ChangeRoleRequest request) => _api.put(
    '/api/admin/users/$userId/role',
    body: request.toJson(),
    decode: (data) => AdminUser.fromJson(asJson(data)),
  );

  /// The user as it is after the change. Admin accounts can't be deactivated.
  Future<AdminUser> setActive(int userId, {required bool isActive}) => _api.put(
    '/api/admin/users/$userId/status',
    body: {'isActive': isActive},
    decode: (data) => AdminUser.fromJson(asJson(data)),
  );

  /// An admin can't reset their own password here; that is Change password in their profile.
  Future<void> resetPassword(int userId, String newPassword) => _api.post(
    '/api/admin/users/$userId/password',
    body: {'newPassword': newPassword},
    decode: ApiClient.ignoreBody,
  );

  Future<AdminUser> updateProfile(int userId, UpdateUserProfileRequest request) => _api.put(
    '/api/admin/users/$userId/profile',
    body: request.toJson(),
    decode: (data) => AdminUser.fromJson(asJson(data)),
  );

  /// Newest first. [entityName] narrows it to one kind of record ("User", "Department"…).
  Future<Paged<AuditLogEntry>> auditLogs({
    String? entityName,
    int page = 1,
    int pageSize = AppConfig.defaultPageSize,
  }) => _api.getPaged(
    '/api/admin/audit-logs',
    page: page,
    pageSize: pageSize,
    query: {'entityName': entityName},
    item: AuditLogEntry.fromJson,
  );

  Future<List<Department>> departments() => _api.get(
    '/api/admin/departments',
    decode: (data) => [for (final item in asJsonList(data)) Department.fromJson(item)],
  );

  Future<Department> createDepartment(String name) => _api.post(
    '/api/admin/departments',
    body: {'name': name},
    decode: (data) => Department.fromJson(asJson(data)),
  );

  Future<Department> renameDepartment(int id, String name) => _api.put(
    '/api/admin/departments/$id',
    body: {'name': name},
    decode: (data) => Department.fromJson(asJson(data)),
  );

  Future<void> deleteDepartment(int id) =>
      _api.delete('/api/admin/departments/$id', decode: ApiClient.ignoreBody);
}

final adminApiProvider = Provider<AdminApi>((ref) => AdminApi(ref.watch(apiClientProvider)));
