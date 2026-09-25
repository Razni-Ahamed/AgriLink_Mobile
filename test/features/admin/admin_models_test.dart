import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/features/admin/data/admin_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_fixtures.dart';

void main() {
  test('AdminMetrics reads every number, and the harvest volume as a decimal', () {
    final metrics = AdminMetrics.fromJson({
      'totalUsers': 120,
      'totalFarms': 40,
      'totalCrops': 75,
      'issuesReported': 30,
      'issuesPending': 4,
      'issuesResolved': 22,
      'harvestVolumeSoldThisMonth': 1250.5,
    });
    expect(metrics.totalUsers, 120);
    expect(metrics.totalFarms, 40);
    expect(metrics.totalCrops, 75);
    expect(metrics.issuesReported, 30);
    expect(metrics.issuesPending, 4);
    expect(metrics.issuesResolved, 22);
    expect(metrics.harvestVolumeSoldThisMonth, 1250.5);
  });

  test('AdminMetrics accepts a whole-number harvest volume', () {
    expect(
      AdminMetrics.fromJson({'harvestVolumeSoldThisMonth': 300}).harvestVolumeSoldThisMonth,
      300,
    );
    expect(AdminMetrics.fromJson({}).totalUsers, 0);
  });

  group('AdminUser', () {
    test('reads an officer with a department', () {
      final user = AdminUser.fromJson(adminUserJson());
      expect(user.role, Role.officer);
      expect(user.department, 'Agriculture');
      expect(user.district, 'Kandy');
      expect(user.isActive, isTrue);
      expect(user.createdAt, DateTime.utc(2026, 5, 1, 9));
      expect(user.canChangeRole, isTrue);
      expect(user.isAdmin, isFalse);
    });

    test('only officers and buyers can be re-typed, and admins are recognised', () {
      expect(AdminUser.fromJson(adminUserJson(role: 'Buyer')).canChangeRole, isTrue);
      expect(AdminUser.fromJson(adminUserJson(role: 'Farmer')).canChangeRole, isFalse);
      final admin = AdminUser.fromJson(
        adminUserJson(role: 'Admin', district: null, department: null),
      );
      expect(admin.canChangeRole, isFalse);
      expect(admin.isAdmin, isTrue);
      expect(admin.district, isNull);
    });
  });

  group('CreateUserRequest', () {
    test('an officer sends the department and no business name', () {
      const request = CreateUserRequest(
        fullName: 'Nimali Silva',
        email: 'nimali@example.lk',
        password: 'Str0ng!Pass',
        role: Role.officer,
        district: 'Kandy',
        departmentId: 3,
        businessName: 'ignored',
      );
      expect(request.toJson(), {
        'fullName': 'Nimali Silva',
        'email': 'nimali@example.lk',
        'password': 'Str0ng!Pass',
        'role': 'Officer',
        'district': 'Kandy',
        'departmentId': 3,
      });
    });

    test('a buyer sends the business name and no department', () {
      const request = CreateUserRequest(
        fullName: 'Sunil Traders',
        email: 'sunil@example.lk',
        password: 'Str0ng!Pass',
        role: Role.buyer,
        district: 'Colombo',
        username: 'sunil.traders',
        departmentId: 3,
        businessName: 'Sunil Traders',
      );
      expect(request.toJson(), {
        'fullName': 'Sunil Traders',
        'email': 'sunil@example.lk',
        'username': 'sunil.traders',
        'password': 'Str0ng!Pass',
        'role': 'Buyer',
        'district': 'Colombo',
        'businessName': 'Sunil Traders',
      });
    });

    test('a blank username is left out so the server makes one', () {
      const request = CreateUserRequest(
        fullName: 'A B',
        email: 'a@example.lk',
        password: 'x',
        role: Role.officer,
        district: 'Kandy',
        username: '',
        departmentId: 1,
      );
      expect(request.toJson().containsKey('username'), isFalse);
    });
  });

  test('ChangeRoleRequest sends only what the new role needs', () {
    expect(
      const ChangeRoleRequest(
        role: Role.officer,
        district: 'Galle',
        departmentId: 2,
        businessName: 'x',
      ).toJson(),
      {'role': 'Officer', 'district': 'Galle', 'departmentId': 2},
    );
    expect(
      const ChangeRoleRequest(
        role: Role.buyer,
        district: 'Galle',
        departmentId: 2,
        businessName: 'Green Traders',
      ).toJson(),
      {'role': 'Buyer', 'district': 'Galle', 'businessName': 'Green Traders'},
    );
  });

  test('UpdateUserProfileRequest leaves out anything not changed', () {
    const request = UpdateUserProfileRequest(fullName: 'New Name', phoneNumber: '0771234567');
    expect(request.toJson(), {'fullName': 'New Name', 'phoneNumber': '0771234567'});
    expect(request.isEmpty, isFalse);
    expect(const UpdateUserProfileRequest().isEmpty, isTrue);
  });

  test('CreatedUser reads the new account', () {
    final user = CreatedUser.fromJson({
      'userId': 9,
      'fullName': 'Nimali Silva',
      'email': 'nimali@example.lk',
      'username': 'nimali.silva',
      'role': 'Officer',
    });
    expect(user.userId, 9);
    expect(user.username, 'nimali.silva');
    expect(user.role, Role.officer);
  });

  test('Department reads its name and date', () {
    final department = Department.fromJson({
      'departmentId': 4,
      'name': 'Agriculture',
      'createdAt': '2026-01-02T00:00:00Z',
    });
    expect(department.departmentId, 4);
    expect(department.name, 'Agriculture');
    expect(department.createdAt, DateTime.utc(2026, 1, 2));
  });

  group('AuditLogEntry', () {
    Map<String, Object?> entry({String? oldValue, String? newValue}) => {
      'auditId': 1,
      'userId': 3,
      'userName': 'Admin One',
      'action': 'UserCreated',
      'entityName': 'User',
      'entityId': 9,
      'oldValue': oldValue,
      'newValue': newValue,
      'createdAt': '2026-09-01T10:15:00Z',
    };

    test('reads who did what to which record', () {
      final log = AuditLogEntry.fromJson(entry(newValue: 'Officer'));
      expect(log.userName, 'Admin One');
      expect(log.action, 'UserCreated');
      expect(log.entityName, 'User');
      expect(log.entityId, 9);
      expect(log.oldValue, isNull);
      expect(log.newValue, 'Officer');
      expect(log.hasValues, isTrue);
      expect(log.createdAt, DateTime.utc(2026, 9, 1, 10, 15));
    });

    test('an entry with no old or new value says so', () {
      expect(AuditLogEntry.fromJson(entry()).hasValues, isFalse);
      expect(AuditLogEntry.fromJson(entry(oldValue: '')).hasValues, isFalse);
    });
  });
}
