import 'package:agrilink_mobile/app/router/app_router.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';
import 'admin_fixtures.dart';

const _strongPassword = 'Str0ng!Passw0rd';

/// The signed-in admin is user 1 (see `profileJson`), so user 1 is "yourself".
class _Backend {
  _Backend() {
    users = [
      adminUserJson(id: 1, name: 'Admin One', role: 'Admin', district: null, department: null),
      adminUserJson(),
      adminUserJson(
        id: 3,
        name: 'Nimali Silva',
        role: 'Buyer',
        district: 'Colombo',
        department: null,
      ),
      adminUserJson(
        id: 4,
        name: 'Sunil Fernando',
        role: 'Farmer',
        isActive: false,
        department: null,
      ),
    ];
    api
      ..on('GET', '/api/users/me', (_) => FakeResponse(200, profileJson(Role.admin)))
      ..on('GET', '/api/admin/users', (_) => FakeResponse(200, users))
      ..on('GET', '/api/districts', (_) => const FakeResponse(200, ['Colombo', 'Kandy', 'Matale']))
      ..on(
        'GET',
        '/api/admin/departments',
        (_) => const FakeResponse(200, [
          {'departmentId': 1, 'name': 'Agriculture', 'createdAt': '2026-01-01T00:00:00Z'},
          {'departmentId': 2, 'name': 'Irrigation', 'createdAt': '2026-01-02T00:00:00Z'},
        ]),
      );
    for (final id in [1, 2, 3, 4]) {
      api
        ..on('PUT', '/api/admin/users/$id/status', (request) {
          final index = users.indexWhere((u) => u['userId'] == id);
          users[index] = {...users[index], 'isActive': request.json['isActive']};
          return FakeResponse(200, users[index]);
        })
        ..on('POST', '/api/admin/users/$id/password', (_) => const FakeResponse(204))
        ..on('PUT', '/api/admin/users/$id/role', (request) {
          final index = users.indexWhere((u) => u['userId'] == id);
          users[index] = {
            ...users[index],
            'role': request.json['role'],
            'district': request.json['district'],
            'department': request.json['departmentId'] == null ? null : 'Irrigation',
          };
          return FakeResponse(200, users[index]);
        })
        ..on('PUT', '/api/admin/users/$id/profile', (request) {
          final index = users.indexWhere((u) => u['userId'] == id);
          users[index] = {
            ...users[index],
            if (request.json['fullName'] != null) 'fullName': request.json['fullName'],
          };
          return FakeResponse(200, users[index]);
        });
    }
  }

  final api = FakeApi();
  late List<Map<String, Object?>> users;
}

void main() {
  late _Backend backend;
  late FakeApi api;

  setUp(() {
    backend = _Backend();
    api = backend.api;
  });

  Future<TestApp> open(WidgetTester tester, int userId, {String language = 'en'}) async {
    final app = await pumpAgriLink(
      tester,
      api: api,
      session: Session(token: fakeJwt(), role: Role.admin),
      language: language,
    );
    app.container.read(routerProvider).go('/admin/users/$userId');
    await tester.pumpAndSettle();
    return app;
  }

  Finder inDialog(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  bool isEnabled(WidgetTester tester, String key) => tester
      .widget<ListTile>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(ListTile)))
      .enabled;

  group('guard rails', () {
    testWidgets('an admin account cannot be deactivated, and the page says why', (tester) async {
      await open(tester, 1);
      expect(find.text("Admin accounts can't be deactivated."), findsOneWidget);
      expect(isEnabled(tester, 'action-active'), isFalse);

      await tester.tap(find.byKey(const Key('action-active')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(api.requests.where((r) => r.method == 'PUT'), isEmpty);
    });

    testWidgets('you cannot reset your own password here', (tester) async {
      await open(tester, 1);
      expect(find.textContaining('use Change password in your profile'), findsOneWidget);
      expect(isEnabled(tester, 'action-password'), isFalse);

      await tester.tap(find.byKey(const Key('action-password')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reset-password')), findsNothing);
    });

    testWidgets("another admin's password can be reset, and yours cannot", (tester) async {
      backend.users.add(
        adminUserJson(id: 5, name: 'Admin Two', role: 'Admin', district: null, department: null),
      );
      await open(tester, 5);
      expect(isEnabled(tester, 'action-password'), isTrue);
    });

    testWidgets('a farmer cannot change role here', (tester) async {
      await open(tester, 4);
      expect(find.text('Only Officer and Buyer accounts can change role here.'), findsOneWidget);
      expect(isEnabled(tester, 'action-role'), isFalse);
    });

    testWidgets('an unknown user says so', (tester) async {
      await open(tester, 99);
      expect(find.text('This user is no longer in the list.'), findsOneWidget);
    });
  });

  testWidgets('the page shows the user and every action', (tester) async {
    await open(tester, 2);
    expect(find.text('Kamal Perera'), findsOneWidget);
    expect(find.text('user2@example.lk'), findsOneWidget);
    expect(find.text('Kandy · Agriculture'), findsOneWidget);
    expect(find.text('Joined May 1, 2026'), findsOneWidget);
    for (final key in ['action-edit', 'action-role', 'action-active', 'action-password']) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    expect(isEnabled(tester, 'action-role'), isTrue);
  });

  group('activate and deactivate', () {
    testWidgets('deactivating asks first, naming the user', (tester) async {
      await open(tester, 2);
      await tester.tap(find.byKey(const Key('action-active')));
      await tester.pumpAndSettle();
      expect(find.text('Deactivate Kamal Perera?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.requests.where((r) => r.method == 'PUT'), isEmpty);
    });

    testWidgets('confirming deactivates and the page shows the new state', (tester) async {
      await open(tester, 2);
      await tester.tap(find.byKey(const Key('action-active')));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Deactivate'));
      await tester.pumpAndSettle();

      expect(api.lastTo('PUT', '/api/admin/users/2/status')!.json, {'isActive': false});
      expect(find.text('Kamal Perera was deactivated.'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.text('Activate'), findsOneWidget);
    });

    testWidgets('an inactive user can be activated again', (tester) async {
      await open(tester, 4);
      await tester.tap(find.byKey(const Key('action-active')));
      await tester.pumpAndSettle();
      expect(find.text('Activate Sunil Fernando?'), findsOneWidget);
      await tester.tap(inDialog('Activate'));
      await tester.pumpAndSettle();

      expect(api.lastTo('PUT', '/api/admin/users/4/status')!.json, {'isActive': true});
      expect(find.text('Sunil Fernando was activated.'), findsOneWidget);
    });

    testWidgets('a change someone else already made is explained and the page reloads', (
      tester,
    ) async {
      await open(tester, 2);
      api.on('PUT', '/api/admin/users/2/status', (_) {
        backend.users[1] = {...backend.users[1], 'isActive': false};
        return const FakeResponse(400, {'message': 'User is already deactivated.'});
      });
      await tester.tap(find.byKey(const Key('action-active')));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Deactivate'));
      await tester.pumpAndSettle();

      expect(find.text('User is already deactivated.'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
    });
  });

  group('reset password', () {
    Future<void> openSheet(WidgetTester tester) async {
      await open(tester, 2);
      await tester.tap(find.byKey(const Key('action-password')));
      await tester.pumpAndSettle();
    }

    testWidgets('a weak password is refused by the password rules', (tester) async {
      await openSheet(tester);
      await tester.fill(find.byKey(const Key('reset-password')), 'short');
      await tester.fill(find.byKey(const Key('reset-confirm')), 'short');
      await tester.tapVisible(find.byKey(const Key('reset-save')));

      expect(find.text('Password must be at least 12 characters'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(api.lastTo('POST', '/api/admin/users/2/password'), isNull);
    });

    testWidgets('the two passwords must match', (tester) async {
      await openSheet(tester);
      await tester.fill(find.byKey(const Key('reset-password')), _strongPassword);
      await tester.fill(find.byKey(const Key('reset-confirm')), '${_strongPassword}x');
      await tester.tapVisible(find.byKey(const Key('reset-save')));

      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(api.lastTo('POST', '/api/admin/users/2/password'), isNull);
    });

    testWidgets('a valid password is confirmed, naming the user, then sent', (tester) async {
      await openSheet(tester);
      await tester.fill(find.byKey(const Key('reset-password')), _strongPassword);
      await tester.fill(find.byKey(const Key('reset-confirm')), _strongPassword);
      await tester.tapVisible(find.byKey(const Key('reset-save')));

      expect(find.text("Reset Kamal Perera's password?"), findsOneWidget);
      expect(api.lastTo('POST', '/api/admin/users/2/password'), isNull);

      await tester.tap(inDialog('Reset Password'));
      await tester.pumpAndSettle();

      expect(api.lastTo('POST', '/api/admin/users/2/password')!.json, {
        'newPassword': _strongPassword,
      });
      expect(find.text("Kamal Perera's password was reset."), findsOneWidget);
      expect(find.byKey(const Key('reset-password')), findsNothing);
    });

    testWidgets('backing out of the confirmation sends nothing and keeps the form', (tester) async {
      await openSheet(tester);
      await tester.fill(find.byKey(const Key('reset-password')), _strongPassword);
      await tester.fill(find.byKey(const Key('reset-confirm')), _strongPassword);
      await tester.tapVisible(find.byKey(const Key('reset-save')));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(api.lastTo('POST', '/api/admin/users/2/password'), isNull);
      expect(find.byKey(const Key('reset-password')), findsOneWidget);
    });

    testWidgets("the server's refusal is shown in the sheet", (tester) async {
      api.on(
        'POST',
        '/api/admin/users/2/password',
        (_) => const FakeResponse(400, {'message': 'Use Change password instead.'}),
      );
      await openSheet(tester);
      await tester.fill(find.byKey(const Key('reset-password')), _strongPassword);
      await tester.fill(find.byKey(const Key('reset-confirm')), _strongPassword);
      await tester.tapVisible(find.byKey(const Key('reset-save')));
      await tester.tap(inDialog('Reset Password'));
      await tester.pumpAndSettle();

      expect(find.text('Use Change password instead.'), findsOneWidget);
      expect(find.byKey(const Key('reset-password')), findsOneWidget);
    });
  });

  group('change role', () {
    testWidgets('an officer becomes a buyer only with a business name', (tester) async {
      await open(tester, 2);
      await tester.tap(find.byKey(const Key('action-role')));
      await tester.pumpAndSettle();
      expect(find.text('Officer → Buyer'), findsOneWidget);

      await tester.tapVisible(find.byKey(const Key('role-save')));
      expect(find.text('Business name is required for Buyer accounts'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await tester.fill(find.byKey(const Key('role-business-name')), 'Green Traders');
      await tester.tapVisible(find.byKey(const Key('role-save')));
      expect(find.text("Change Kamal Perera's role?"), findsOneWidget);
      expect(find.text('Kamal Perera will become a Buyer.'), findsOneWidget);
      expect(api.lastTo('PUT', '/api/admin/users/2/role'), isNull);

      await tester.tap(inDialog('Update Role'));
      await tester.pumpAndSettle();
      expect(api.lastTo('PUT', '/api/admin/users/2/role')!.json, {
        'role': 'Buyer',
        'district': 'Kandy',
        'businessName': 'Green Traders',
      });
      expect(find.text('Kamal Perera is now a Buyer.'), findsOneWidget);
    });

    testWidgets('a buyer becomes an officer only with a department', (tester) async {
      await open(tester, 3);
      await tester.tap(find.byKey(const Key('action-role')));
      await tester.pumpAndSettle();
      expect(find.text('Buyer → Officer'), findsOneWidget);

      await tester.tapVisible(find.byKey(const Key('role-save')));
      expect(find.text('Department is required for Officer accounts'), findsWidgets);
      expect(api.lastTo('PUT', '/api/admin/users/3/role'), isNull);

      await tester.tapVisible(find.byKey(const Key('role-department')));
      await tester.tap(find.text('Irrigation').last);
      await tester.pumpAndSettle();
      await tester.tapVisible(find.byKey(const Key('role-save')));
      await tester.tap(inDialog('Update Role'));
      await tester.pumpAndSettle();

      expect(api.lastTo('PUT', '/api/admin/users/3/role')!.json, {
        'role': 'Officer',
        'district': 'Colombo',
        'departmentId': 2,
      });
      expect(find.text('Nimali Silva is now a Officer.'), findsOneWidget);
    });
  });

  group('edit profile', () {
    testWidgets('an officer sees no NIC, business or plot fields', (tester) async {
      await open(tester, 2);
      await tester.tap(find.byKey(const Key('action-edit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit-full-name')), findsOneWidget);
      expect(find.byKey(const Key('edit-phone')), findsOneWidget);
      expect(find.byKey(const Key('edit-nic')), findsNothing);
      expect(find.byKey(const Key('edit-business-name')), findsNothing);
      expect(find.byKey(const Key('edit-field-plot')), findsNothing);
    });

    testWidgets('a buyer has a NIC and business details, a farmer a plot', (tester) async {
      await open(tester, 3);
      await tester.tap(find.byKey(const Key('action-edit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('edit-nic')), findsOneWidget);
      await tester.reveal(find.byKey(const Key('edit-business-reg')));
      expect(find.byKey(const Key('edit-business-name')), findsOneWidget);
      expect(find.byKey(const Key('edit-field-plot')), findsNothing);
    });

    testWidgets('a farmer has a plot and no business details', (tester) async {
      await open(tester, 4);
      await tester.tap(find.byKey(const Key('action-edit')));
      await tester.pumpAndSettle();
      await tester.reveal(find.byKey(const Key('edit-field-plot')));
      expect(find.byKey(const Key('edit-field-plot')), findsOneWidget);
      expect(find.byKey(const Key('edit-business-name')), findsNothing);
    });

    testWidgets('saving without changing anything says there is nothing to save', (tester) async {
      await open(tester, 2);
      await tester.tap(find.byKey(const Key('action-edit')));
      await tester.pumpAndSettle();
      await tester.tapVisible(find.byKey(const Key('edit-save')));

      expect(find.text('There were no changes to save.'), findsOneWidget);
      expect(api.lastTo('PUT', '/api/admin/users/2/profile'), isNull);
    });

    testWidgets('a bad phone number is refused', (tester) async {
      await open(tester, 2);
      await tester.tap(find.byKey(const Key('action-edit')));
      await tester.pumpAndSettle();
      await tester.fill(find.byKey(const Key('edit-phone')), '12345');
      await tester.tapVisible(find.byKey(const Key('edit-save')));

      expect(find.text('Phone number must be 10 digits'), findsOneWidget);
      expect(api.lastTo('PUT', '/api/admin/users/2/profile'), isNull);
    });

    testWidgets('only the fields that changed are sent', (tester) async {
      await open(tester, 2);
      await tester.tap(find.byKey(const Key('action-edit')));
      await tester.pumpAndSettle();
      await tester.fill(find.byKey(const Key('edit-full-name')), 'Kamal P. Perera');
      await tester.fill(find.byKey(const Key('edit-phone')), '077 123 4567');
      await tester.tapVisible(find.byKey(const Key('edit-save')));

      expect(api.lastTo('PUT', '/api/admin/users/2/profile')!.json, {
        'fullName': 'Kamal P. Perera',
        'phoneNumber': '0771234567',
      });
      expect(find.text("Kamal P. Perera's profile was updated."), findsOneWidget);
      expect(find.text('Kamal P. Perera'), findsOneWidget);
    });

    testWidgets('an email another account already has is explained', (tester) async {
      api.on(
        'PUT',
        '/api/admin/users/2/profile',
        (_) => const FakeResponse(409, {'message': 'An account with this email already exists.'}),
      );
      await open(tester, 2);
      await tester.tap(find.byKey(const Key('action-edit')));
      await tester.pumpAndSettle();
      await tester.fill(find.byKey(const Key('edit-email')), 'taken@example.lk');
      await tester.tapVisible(find.byKey(const Key('edit-save')));

      expect(find.text('An account with this email already exists.'), findsOneWidget);
      // The sheet stays open so it can be corrected.
      expect(find.byKey(const Key('edit-email')), findsOneWidget);
    });
  });

  testWidgets('the detail page fits a narrow screen in Tamil', (tester) async {
    final app = await pumpAgriLink(
      tester,
      api: api,
      session: Session(token: fakeJwt(), role: Role.admin),
      language: 'ta',
      screen: const Size(320, 640),
    );
    app.container.read(routerProvider).go('/admin/users/2');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Kamal Perera'), findsOneWidget);
  });
}
