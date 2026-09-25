import 'package:agrilink_mobile/app/router/app_router.dart';
import 'package:agrilink_mobile/app/router/app_routes.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';

Map<String, Object?> departmentJson(int id, String name) => {
  'departmentId': id,
  'name': name,
  'createdAt': '2026-03-0${id}T12:00:00Z',
};

void main() {
  late FakeApi api;
  late List<Map<String, Object?>> departments;

  setUp(() {
    departments = [departmentJson(1, 'Agriculture'), departmentJson(2, 'Irrigation')];
    api = FakeApi()
      ..on('GET', '/api/users/me', (_) => FakeResponse(200, profileJson(Role.admin)))
      ..on('GET', '/api/admin/users', (_) => const FakeResponse(200, <Object?>[]))
      ..on('GET', '/api/admin/departments', (_) => FakeResponse(200, departments));
  });

  Future<TestApp> open(WidgetTester tester, {String language = 'en', Size? screen}) async {
    final app = await pumpAgriLink(
      tester,
      api: api,
      session: Session(token: fakeJwt(), role: Role.admin),
      language: language,
      screen: screen ?? const Size(390, 844),
    );
    app.container.read(routerProvider).go(AppRoutes.adminDepartments);
    await tester.pumpAndSettle();
    return app;
  }

  Finder inDialog(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  testWidgets('lists each department with its created date', (tester) async {
    await open(tester);
    expect(find.text('Agriculture'), findsOneWidget);
    expect(find.text('Irrigation'), findsOneWidget);
    expect(find.text('Created Mar 1, 2026'), findsOneWidget);
  });

  testWidgets('an empty list says so', (tester) async {
    departments.clear();
    await open(tester);
    expect(find.text('No departments yet.'), findsOneWidget);
  });

  testWidgets('a failed load shows an error with Try again', (tester) async {
    api.offline('GET', '/api/admin/departments');
    await open(tester);
    expect(find.text('Try again'), findsOneWidget);
  });

  group('add', () {
    testWidgets('a name is required', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('add-department')));
      await tester.pumpAndSettle();
      await tester.tapVisible(find.byKey(const Key('department-save')));

      expect(find.text('Department name is required'), findsOneWidget);
      expect(api.lastTo('POST', '/api/admin/departments'), isNull);
    });

    testWidgets('a new department is sent trimmed and appears in the list', (tester) async {
      api.on('POST', '/api/admin/departments', (request) {
        final created = departmentJson(3, request.json['name']! as String);
        departments.add(created);
        return FakeResponse(201, created);
      });
      await open(tester);
      await tester.tap(find.byKey(const Key('add-department')));
      await tester.pumpAndSettle();
      await tester.fill(find.byKey(const Key('department-name')), '  Livestock ');
      await tester.tapVisible(find.byKey(const Key('department-save')));

      expect(api.lastTo('POST', '/api/admin/departments')!.json, {'name': 'Livestock'});
      expect(find.text('"Livestock" was created.'), findsOneWidget);
      expect(find.text('Livestock'), findsWidgets);
    });

    testWidgets('a name that already exists is explained and the sheet stays open', (tester) async {
      api.on(
        'POST',
        '/api/admin/departments',
        (_) => const FakeResponse(409, {'message': 'A department with this name already exists.'}),
      );
      await open(tester);
      await tester.tap(find.byKey(const Key('add-department')));
      await tester.pumpAndSettle();
      await tester.fill(find.byKey(const Key('department-name')), 'Agriculture');
      await tester.tapVisible(find.byKey(const Key('department-save')));

      expect(find.text('A department with this name already exists.'), findsOneWidget);
      expect(find.byKey(const Key('department-name')), findsOneWidget);
    });
  });

  group('rename', () {
    testWidgets('the sheet starts with the current name and sends the new one', (tester) async {
      api.on('PUT', '/api/admin/departments/2', (request) {
        departments[1] = departmentJson(2, request.json['name']! as String);
        return FakeResponse(200, departments[1]);
      });
      await open(tester);
      await tester.tap(find.byKey(const Key('rename-2')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(find.byKey(const Key('department-name'))).controller!.text,
        'Irrigation',
      );

      await tester.fill(find.byKey(const Key('department-name')), 'Water Management');
      await tester.tapVisible(find.byKey(const Key('department-save')));

      expect(api.lastTo('PUT', '/api/admin/departments/2')!.json, {'name': 'Water Management'});
      expect(find.text('Renamed to "Water Management".'), findsOneWidget);
      expect(find.text('Irrigation'), findsNothing);
    });

    testWidgets('a rename to a taken name is explained', (tester) async {
      api.on(
        'PUT',
        '/api/admin/departments/2',
        (_) => const FakeResponse(409, {'message': 'A department with this name already exists.'}),
      );
      await open(tester);
      await tester.tap(find.byKey(const Key('rename-2')));
      await tester.pumpAndSettle();
      await tester.fill(find.byKey(const Key('department-name')), 'Agriculture');
      await tester.tapVisible(find.byKey(const Key('department-save')));

      expect(find.text('A department with this name already exists.'), findsOneWidget);
    });
  });

  group('delete', () {
    testWidgets('asks first, naming the department, and can be cancelled', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('delete-2')));
      await tester.pumpAndSettle();
      expect(find.text('Delete department?'), findsOneWidget);
      expect(
        find.text('This will permanently delete "Irrigation". This can\'t be undone.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.requests.where((r) => r.method == 'DELETE'), isEmpty);
      expect(find.text('Irrigation'), findsOneWidget);
    });

    testWidgets('confirming deletes it', (tester) async {
      api.on('DELETE', '/api/admin/departments/2', (_) {
        departments.removeAt(1);
        return const FakeResponse(204);
      });
      await open(tester);
      await tester.tap(find.byKey(const Key('delete-2')));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Delete'));
      await tester.pumpAndSettle();

      expect(api.lastTo('DELETE', '/api/admin/departments/2'), isNotNull);
      expect(find.text('"Irrigation" was deleted.'), findsOneWidget);
      expect(find.text('Irrigation'), findsNothing);
    });

    testWidgets('a department that still has officers is kept, with the reason shown', (
      tester,
    ) async {
      api.on(
        'DELETE',
        '/api/admin/departments/2',
        (_) => const FakeResponse(400, {
          'message':
              'This department has officers assigned to it. Reassign them before deleting it.',
        }),
      );
      await open(tester);
      await tester.tap(find.byKey(const Key('delete-2')));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('This department has officers assigned to it. Reassign them before deleting it.'),
        findsOneWidget,
      );
      expect(find.text('Irrigation'), findsOneWidget);
    });
  });

  testWidgets('the icon buttons have labels naming the department', (tester) async {
    await open(tester);
    expect(find.byTooltip('Rename: Agriculture'), findsOneWidget);
    expect(find.byTooltip('Delete: Agriculture'), findsOneWidget);
  });

  testWidgets('the cards fit a narrow screen in Tamil', (tester) async {
    await open(tester, language: 'ta', screen: const Size(320, 640));
    expect(tester.takeException(), isNull);
    expect(find.text('Agriculture'), findsOneWidget);
  });
}
