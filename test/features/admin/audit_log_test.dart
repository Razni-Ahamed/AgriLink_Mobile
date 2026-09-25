import 'package:agrilink_mobile/app/router/app_router.dart';
import 'package:agrilink_mobile/app/router/app_routes.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:agrilink_mobile/features/admin/application/audit_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';

Map<String, Object?> auditJson(
  int id, {
  String action = 'UserCreated',
  String entity = 'User',
  String? oldValue,
  String? newValue = 'Officer',
  String actor = 'Admin One',
}) => {
  'auditId': id,
  'userId': 1,
  'userName': actor,
  'action': action,
  'entityName': entity,
  'entityId': 40 + id,
  'oldValue': oldValue,
  'newValue': newValue,
  'createdAt': '2026-09-2${id % 10}T10:15:00Z',
};

void main() {
  group('humanizeAuditAction', () {
    test('splits an identifier into words', () {
      expect(humanizeAuditAction('UserCreated'), 'User created');
      expect(humanizeAuditAction('SecurityReauthFailed'), 'Security reauth failed');
      expect(
        humanizeAuditAction('PurchaseRequestAutoCancelled'),
        'Purchase request auto cancelled',
      );
    });

    test('leaves a single word and an empty action alone', () {
      expect(humanizeAuditAction('Login'), 'Login');
      expect(humanizeAuditAction(''), '');
    });
  });

  group('the audit log screen', () {
    late FakeApi api;
    late List<Map<String, Object?>> entries;

    /// A fake server that honours `entityName`, `page` and `pageSize`.
    void serve() {
      api.on('GET', '/api/admin/audit-logs', (request) {
        final entity = request.query['entityName'];
        final all = [
          for (final e in entries)
            if (entity == null || e['entityName'] == entity) e,
        ];
        final page = int.parse(request.query['page'] ?? '1');
        final pageSize = int.parse(request.query['pageSize'] ?? '20');
        return FakeResponse(200, {
          'items': all.skip((page - 1) * pageSize).take(pageSize).toList(),
          'page': page,
          'pageSize': pageSize,
          'totalCount': all.length,
          'totalPages': (all.length / pageSize).ceil(),
        });
      });
    }

    setUp(() {
      entries = [
        auditJson(1),
        auditJson(
          2,
          action: 'DepartmentRenamed',
          entity: 'Department',
          oldValue: 'Irrigation',
          newValue: 'Water Management',
          actor: 'Admin Two',
        ),
        auditJson(3, action: 'UserDeactivated', newValue: null),
      ];
      api = FakeApi()
        ..on('GET', '/api/users/me', (_) => FakeResponse(200, profileJson(Role.admin)));
      serve();
    });

    Future<TestApp> open(WidgetTester tester, {String language = 'en', Size? screen}) async {
      final app = await pumpAgriLink(
        tester,
        api: api,
        session: Session(token: fakeJwt(), role: Role.admin),
        language: language,
        screen: screen ?? const Size(390, 844),
      );
      app.container.read(routerProvider).go(AppRoutes.adminAuditLog);
      await tester.pumpAndSettle();
      return app;
    }

    testWidgets('each entry says what was done, by whom, to which record', (tester) async {
      await open(tester);
      expect(find.text('User created'), findsOneWidget);
      expect(find.text('Department renamed'), findsOneWidget);
      // The time itself follows the phone's time zone, so only the actor is checked.
      expect(find.textContaining('By Admin Two · Sep 2'), findsOneWidget);
      expect(find.text('Department #42'), findsOneWidget);
      expect(find.text('User #41'), findsOneWidget);
    });

    testWidgets('an entry with values opens to show before and after', (tester) async {
      await open(tester);
      expect(find.text('Water Management'), findsNothing);

      await tester.tap(find.text('Department renamed'));
      await tester.pumpAndSettle();
      expect(find.text('Before'), findsOneWidget);
      expect(find.text('Irrigation'), findsOneWidget);
      expect(find.text('After'), findsOneWidget);
      expect(find.text('Water Management'), findsOneWidget);
    });

    testWidgets('a value that was not recorded says so', (tester) async {
      await open(tester);
      await tester.tap(find.text('User created'));
      await tester.pumpAndSettle();
      expect(find.text('Not recorded'), findsOneWidget);
      expect(find.text('Officer'), findsOneWidget);
    });

    testWidgets('an entry with no values has nothing to open', (tester) async {
      await open(tester);
      expect(find.text('User deactivated'), findsOneWidget);
      expect(
        find.ancestor(of: find.text('User deactivated'), matching: find.byType(ExpansionTile)),
        findsNothing,
      );
    });

    testWidgets('choosing a record type asks the server for only that kind', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('entity-Department')));
      await tester.pumpAndSettle();

      expect(api.lastTo('GET', '/api/admin/audit-logs')!.query['entityName'], 'Department');
      expect(find.text('Department renamed'), findsOneWidget);
      expect(find.text('User created'), findsNothing);
    });

    testWidgets('All removes the filter again', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('entity-Department')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('entity-all')));
      await tester.pumpAndSettle();

      expect(api.lastTo('GET', '/api/admin/audit-logs')!.query.containsKey('entityName'), isFalse);
      expect(find.text('User created'), findsOneWidget);
      expect(find.text('Department renamed'), findsOneWidget);
    });

    testWidgets('a kind with no entries shows the empty message', (tester) async {
      await open(tester);
      // The chip row scrolls sideways, so Order starts off screen.
      await tester.tapVisible(find.byKey(const Key('entity-Order')));
      expect(api.lastTo('GET', '/api/admin/audit-logs')!.query['entityName'], 'Order');
      expect(find.text('No audit entries yet.'), findsOneWidget);
    });

    testWidgets('scrolling to the end loads the next page', (tester) async {
      entries = [for (var i = 1; i <= 45; i++) auditJson(i, newValue: null)];
      await open(tester);
      expect(api.requests.where((r) => r.path == '/api/admin/audit-logs').length, 1);

      await tester.drag(find.byType(ListView).first, const Offset(0, -6000));
      await tester.pumpAndSettle();
      final pages = [
        for (final r in api.requests.where((r) => r.path == '/api/admin/audit-logs'))
          r.query['page'],
      ];
      expect(pages, containsAll(['1', '2']));
    });

    testWidgets('a failed load shows an error with Try again', (tester) async {
      api.offline('GET', '/api/admin/audit-logs');
      await open(tester);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('the cards and chips fit a narrow screen in Sinhala', (tester) async {
      await open(tester, language: 'si', screen: const Size(320, 640));
      expect(tester.takeException(), isNull);
      expect(find.text('User created'), findsOneWidget);
    });
  });
}
