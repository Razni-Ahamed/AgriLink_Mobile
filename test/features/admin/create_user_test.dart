import 'package:agrilink_mobile/app/router/app_router.dart';
import 'package:agrilink_mobile/app/router/app_routes.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:agrilink_mobile/shared/widgets/district_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';
import 'admin_fixtures.dart';

const _password = 'Str0ng!Passw0rd';

void main() {
  late FakeApi api;
  late bool hasDepartments;
  late List<Map<String, Object?>> users;

  setUp(() {
    hasDepartments = true;
    users = [adminUserJson()];
    api = FakeApi()
      ..on('GET', '/api/users/me', (_) => FakeResponse(200, profileJson(Role.admin)))
      ..on('GET', '/api/admin/users', (_) => FakeResponse(200, users))
      ..on('GET', '/api/districts', (_) => const FakeResponse(200, ['Colombo', 'Kandy', 'Matale']))
      ..on(
        'GET',
        '/api/admin/departments',
        (_) => FakeResponse(200, [
          if (hasDepartments) ...[
            {'departmentId': 1, 'name': 'Agriculture', 'createdAt': '2026-01-01T00:00:00Z'},
            {'departmentId': 2, 'name': 'Irrigation', 'createdAt': '2026-01-02T00:00:00Z'},
          ],
        ]),
      );
  });

  Future<TestApp> open(WidgetTester tester, {String language = 'en', Size? screen}) async {
    final app = await pumpAgriLink(
      tester,
      api: api,
      session: Session(token: fakeJwt(), role: Role.admin),
      language: language,
      screen: screen ?? const Size(390, 844),
    );
    app.container.read(routerProvider).go('${AppRoutes.adminUsers}/new');
    await tester.pumpAndSettle();
    return app;
  }

  Finder field(String key) => find.byKey(Key(key));

  Future<void> fillCommon(WidgetTester tester, {String password = _password}) async {
    await tester.fill(field('create-full-name'), 'Nimali Silva');
    await tester.fill(field('create-email'), 'nimali@example.lk');
    await tester.fill(field('create-password'), password);
    await tester.fill(field('create-confirm'), password);
    await tester.tapVisible(find.byType(DistrictPicker));
    await tester.tap(find.text('Kandy'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseDepartment(WidgetTester tester, String name) async {
    await tester.tapVisible(field('create-department'));
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) => tester.tapVisible(field('create-submit'));

  void serverCreates(String role, {String username = 'nimali.silva'}) {
    api.on('POST', '/api/admin/users', (request) {
      users.add(
        adminUserJson(
          id: 9,
          name: request.json['fullName']! as String,
          role: role,
          department: null,
        ),
      );
      return FakeResponse(201, {
        'userId': 9,
        'fullName': request.json['fullName'],
        'email': request.json['email'],
        'username': username,
        'role': role,
      });
    });
  }

  testWidgets('an officer needs a department, a buyer a business name', (tester) async {
    await open(tester);
    expect(field('create-department'), findsOneWidget);
    expect(field('create-business-name'), findsNothing);

    await tester.tapVisible(find.text('Buyer'));
    expect(field('create-department'), findsNothing);
    expect(field('create-business-name'), findsOneWidget);
  });

  testWidgets('an officer cannot be created without a department', (tester) async {
    await open(tester);
    await fillCommon(tester);
    await submit(tester);

    expect(find.text('Department is required for Officer accounts'), findsWidgets);
    expect(api.lastTo('POST', '/api/admin/users'), isNull);
  });

  testWidgets('a buyer cannot be created without a business name', (tester) async {
    await open(tester);
    await tester.tapVisible(find.text('Buyer'));
    await fillCommon(tester);
    await submit(tester);

    expect(find.text('Business name is required for Buyer accounts'), findsOneWidget);
    expect(api.lastTo('POST', '/api/admin/users'), isNull);
  });

  testWidgets('the password must follow the password rules', (tester) async {
    await open(tester);
    await fillCommon(tester, password: 'short');
    await chooseDepartment(tester, 'Agriculture');
    await submit(tester);

    expect(find.text('Password must be at least 12 characters'), findsOneWidget);
    expect(api.lastTo('POST', '/api/admin/users'), isNull);
  });

  testWidgets('the two passwords must match', (tester) async {
    await open(tester);
    await fillCommon(tester);
    await tester.fill(field('create-confirm'), '${_password}x');
    await chooseDepartment(tester, 'Agriculture');
    await submit(tester);

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(api.lastTo('POST', '/api/admin/users'), isNull);
  });

  testWidgets('a district is required', (tester) async {
    await open(tester);
    await tester.fill(field('create-full-name'), 'Nimali Silva');
    await tester.fill(field('create-email'), 'nimali@example.lk');
    await tester.fill(field('create-password'), _password);
    await tester.fill(field('create-confirm'), _password);
    await chooseDepartment(tester, 'Agriculture');
    await submit(tester);

    expect(find.text('District is required'), findsOneWidget);
    expect(api.lastTo('POST', '/api/admin/users'), isNull);
  });

  testWidgets('creating an officer sends the department and shows the new account', (tester) async {
    serverCreates('Officer');
    await open(tester);
    await fillCommon(tester);
    await chooseDepartment(tester, 'Irrigation');
    await submit(tester);

    expect(api.lastTo('POST', '/api/admin/users')!.json, {
      'fullName': 'Nimali Silva',
      'email': 'nimali@example.lk',
      'password': _password,
      'role': 'Officer',
      'district': 'Kandy',
      'departmentId': 2,
    });
    expect(find.text('Account created'), findsOneWidget);
    expect(
      find.text('Nimali Silva was created as Officer with the username nimali.silva.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('created-username')), findsOneWidget);
    // The password is never shown again.
    expect(find.text(_password), findsNothing);
  });

  testWidgets('creating a buyer sends the business name and a cleaned-up username', (tester) async {
    serverCreates('Buyer', username: 'green.traders');
    await open(tester);
    await tester.tapVisible(find.text('Buyer'));
    await fillCommon(tester);
    await tester.fill(field('create-business-name'), 'Green Traders');
    await tester.fill(field('create-username'), '  Green.Traders ');
    await submit(tester);

    expect(api.lastTo('POST', '/api/admin/users')!.json, {
      'fullName': 'Nimali Silva',
      'email': 'nimali@example.lk',
      'username': 'green.traders',
      'password': _password,
      'role': 'Buyer',
      'district': 'Kandy',
      'businessName': 'Green Traders',
    });
    expect(find.text('Account created'), findsOneWidget);
  });

  testWidgets('an invalid username is refused before anything is sent', (tester) async {
    await open(tester);
    await fillCommon(tester);
    await tester.fill(field('create-username'), 'a');
    await chooseDepartment(tester, 'Agriculture');
    await submit(tester);

    expect(find.text('Username must be at least 3 characters'), findsOneWidget);
    expect(api.lastTo('POST', '/api/admin/users'), isNull);
  });

  testWidgets("an email that's already taken is explained, and the form stays", (tester) async {
    api.on(
      'POST',
      '/api/admin/users',
      (_) => const FakeResponse(409, {'message': 'An account with this email already exists.'}),
    );
    await open(tester);
    await fillCommon(tester);
    await chooseDepartment(tester, 'Agriculture');
    await submit(tester);

    expect(find.text('An account with this email already exists.'), findsOneWidget);
    expect(field('create-email'), findsOneWidget);
  });

  testWidgets("the server's reason for a refusal is shown", (tester) async {
    api.on(
      'POST',
      '/api/admin/users',
      (_) => const FakeResponse(400, {'message': 'The selected department does not exist.'}),
    );
    await open(tester);
    await fillCommon(tester);
    await chooseDepartment(tester, 'Agriculture');
    await submit(tester);

    expect(find.text('The selected department does not exist.'), findsOneWidget);
  });

  testWidgets('with no departments yet, an officer cannot be created and the page says so', (
    tester,
  ) async {
    hasDepartments = false;
    await open(tester);
    expect(
      find.text(
        'No departments yet — create one on the Departments page before adding an Officer.',
      ),
      findsOneWidget,
    );
    await fillCommon(tester);
    await submit(tester);
    expect(api.lastTo('POST', '/api/admin/users'), isNull);
  });

  testWidgets('create another starts an empty form', (tester) async {
    serverCreates('Officer');
    await open(tester);
    await fillCommon(tester);
    await chooseDepartment(tester, 'Agriculture');
    await submit(tester);
    await tester.tapVisible(find.byKey(const Key('created-another')));

    expect(find.text('Account created'), findsNothing);
    expect(tester.widget<TextFormField>(field('create-full-name')).controller!.text, isEmpty);
    expect(tester.widget<TextFormField>(field('create-password')).controller!.text, isEmpty);
  });

  testWidgets('back to users returns to the list', (tester) async {
    serverCreates('Officer');
    await open(tester);
    await fillCommon(tester);
    await chooseDepartment(tester, 'Agriculture');
    await submit(tester);
    await tester.tapVisible(find.byKey(const Key('created-back')));

    // Back on the list, which reloads and now includes the new account.
    expect(find.byKey(const Key('user-search')), findsOneWidget);
    expect(find.text('Nimali Silva'), findsOneWidget);
    expect(find.text('Showing 2 of 2 users'), findsOneWidget);
  });

  testWidgets('the users list offers Create User', (tester) async {
    final app = await pumpAgriLink(
      tester,
      api: api,
      session: Session(token: fakeJwt(), role: Role.admin),
    );
    app.container.read(routerProvider).go(AppRoutes.adminUsers);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-user')));
    await tester.pumpAndSettle();
    expect(field('create-full-name'), findsOneWidget);
  });

  testWidgets('the form fits a narrow screen in Sinhala', (tester) async {
    await open(tester, language: 'si', screen: const Size(320, 640));
    expect(tester.takeException(), isNull);
    expect(field('create-full-name'), findsOneWidget);
  });
}
