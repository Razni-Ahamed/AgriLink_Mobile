import 'package:agrilink_mobile/app/router/app_router.dart';
import 'package:agrilink_mobile/app/router/app_routes.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:agrilink_mobile/features/officer/data/approvals_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';

Map<String, Object?> farmerApplicationJson({int id = 11, String name = 'Nimal Silva'}) => {
  'userId': id,
  'fullName': name,
  'email': 'nimal$id@example.lk',
  'role': 'Farmer',
  'district': 'Kandy',
  'nic': '851234567V',
  'createdAt': '2026-09-20T08:30:00Z',
  'fieldPlotNumber': 'KD-12',
  'phoneNumber': '0771234567',
};

Map<String, Object?> buyerApplicationJson({int id = 21, String name = 'Sunil Traders'}) => {
  'userId': id,
  'fullName': name,
  'email': 'buyer$id@example.lk',
  'role': 'Buyer',
  'district': 'Colombo',
  'nic': '901234567V',
  'createdAt': '2026-09-21T08:30:00Z',
  'businessRegistrationNumber': 'PV-1234',
  'businessPhone': '0112345678',
  'legalBusinessName': 'Sunil Traders (Pvt) Ltd',
};

Map<String, Object?> changeRequestJson({
  int id = 5,
  String field = 'Email',
  String oldValue = 'old@example.lk',
  String newValue = 'new@example.lk',
}) => {
  'requestId': id,
  'userId': 11,
  'fullName': 'Nimal Silva',
  'username': 'nimal',
  'role': 'Farmer',
  'profilePhotoUrl': null,
  'district': 'Kandy',
  'field': field,
  'oldValue': oldValue,
  'newValue': newValue,
  'requestedAt': '2026-09-22T10:00:00Z',
};

Map<String, Object?> pagedJson(List<Object?> items) => {
  'items': items,
  'page': 1,
  'pageSize': 20,
  'totalCount': items.length,
  'totalPages': 1,
};

void main() {
  group('models', () {
    test('a farmer application keeps the farmer fields', () {
      final a = PendingRegistration.fromJson(farmerApplicationJson());
      expect(a.role, Role.farmer);
      expect(a.isFarmer, isTrue);
      expect(a.fieldPlotNumber, 'KD-12');
      expect(a.phoneNumber, '0771234567');
      expect(a.legalBusinessName, isNull);
      expect(a.createdAt, DateTime.utc(2026, 9, 20, 8, 30));
    });

    test('a buyer application keeps the business fields', () {
      final a = PendingRegistration.fromJson(buyerApplicationJson());
      expect(a.role, Role.buyer);
      expect(a.isFarmer, isFalse);
      expect(a.legalBusinessName, 'Sunil Traders (Pvt) Ltd');
      expect(a.businessRegistrationNumber, 'PV-1234');
      expect(a.businessPhone, '0112345678');
      expect(a.phoneNumber, isNull);
    });

    test('a change request reads old and new values', () {
      final r = PendingChangeRequest.fromJson(changeRequestJson(field: 'NIC'));
      expect(r.changeField, ChangeRequestField.nic);
      expect(r.oldValue, 'old@example.lk');
      expect(r.newValue, 'new@example.lk');
      expect(r.district, 'Kandy');
      expect(r.requestedAt, DateTime.utc(2026, 9, 22, 10));
    });

    test('a change request for a field the app does not know is refused', () {
      expect(
        () => PendingChangeRequest.fromJson(changeRequestJson(field: 'Phone')),
        throwsFormatException,
      );
    });
  });

  group('the approvals screen', () {
    late FakeApi api;
    late List<Map<String, Object?>> applications;
    late List<Map<String, Object?>> changes;

    setUp(() {
      api = FakeApi();
      applications = [farmerApplicationJson()];
      changes = [changeRequestJson()];
      api
        ..on('GET', '/api/registrations/pending', (_) => FakeResponse(200, applications))
        ..on(
          'GET',
          '/api/profile-change-requests/pending',
          (_) => FakeResponse(200, pagedJson(changes)),
        );
    });

    Future<TestApp> open(
      WidgetTester tester,
      Role role, {
      String language = 'en',
      Size screen = const Size(390, 844),
    }) async {
      api.on('GET', '/api/users/me', (_) => FakeResponse(200, profileJson(role)));
      final app = await pumpAgriLink(
        tester,
        api: api,
        session: Session(token: fakeJwt(), role: role),
        language: language,
        screen: screen,
      );
      app.container.read(routerProvider).go(AppRoutes.approvals);
      await tester.pumpAndSettle();
      return app;
    }

    Finder inDialog(String text) =>
        find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

    Future<void> openProfileChanges(WidgetTester tester) async {
      await tester.tap(find.text('Profile changes'));
      await tester.pumpAndSettle();
    }

    testWidgets('an officer sees the applications, limited to their district', (tester) async {
      await open(tester, Role.officer);
      expect(find.text('Nimal Silva'), findsOneWidget);
      expect(find.text('Farmer application'), findsOneWidget);
      expect(find.text('Plot: KD-12'), findsOneWidget);
      expect(find.text('Showing Farmer applications in Kandy'), findsOneWidget);
    });

    testWidgets('an admin also sees buyer applications and that it covers every district', (
      tester,
    ) async {
      applications.add(buyerApplicationJson());
      await open(tester, Role.admin);
      expect(
        find.text('Showing Farmer and Buyer applications from every district'),
        findsOneWidget,
      );
      expect(find.text('Buyer application'), findsOneWidget);
      expect(find.text('Business: Sunil Traders (Pvt) Ltd'), findsOneWidget);
      expect(find.text('Reg. no: PV-1234'), findsOneWidget);
    });

    testWidgets('an empty queue says so', (tester) async {
      applications.clear();
      await open(tester, Role.officer);
      expect(find.text('No applications are waiting for review right now.'), findsOneWidget);
    });

    testWidgets('rejecting needs a reason, which is then sent', (tester) async {
      await open(tester, Role.officer);
      await tester.tapVisible(find.byKey(const Key('reject')));

      await tester.tapVisible(find.byKey(const Key('reject-submit')));
      expect(find.text('Please give a reason.'), findsOneWidget);
      expect(api.lastTo('POST', '/api/registrations/11/reject'), isNull);

      await tester.fill(find.byKey(const Key('reject-reason')), '  NIC does not match  ');
      api.on('POST', '/api/registrations/11/reject', (_) {
        applications.clear();
        return const FakeResponse(200, {});
      });
      await tester.tapVisible(find.byKey(const Key('reject-submit')));

      expect(api.lastTo('POST', '/api/registrations/11/reject')!.json, {
        'reason': 'NIC does not match',
      });
      expect(find.text('Nimal Silva was rejected.'), findsOneWidget);
      expect(find.text('No applications are waiting for review right now.'), findsOneWidget);
    });

    testWidgets('approving asks first, naming the applicant', (tester) async {
      await open(tester, Role.officer);
      await tester.tapVisible(find.byKey(const Key('approve')));
      expect(find.text('Approve this application?'), findsOneWidget);
      expect(find.textContaining('Nimal Silva (Farmer)'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.lastTo('POST', '/api/registrations/11/approve'), isNull);
    });

    testWidgets('confirming approves and refreshes the list', (tester) async {
      await open(tester, Role.officer);
      api.on('POST', '/api/registrations/11/approve', (_) {
        applications.clear();
        return const FakeResponse(200, {});
      });
      await tester.tapVisible(find.byKey(const Key('approve')));
      await tester.tap(inDialog('Approve'));
      await tester.pumpAndSettle();

      expect(api.lastTo('POST', '/api/registrations/11/approve'), isNotNull);
      expect(find.text('Nimal Silva was approved.'), findsOneWidget);
      expect(find.text('Nimal Silva'), findsNothing);
    });

    testWidgets('an application someone else already decided is explained and removed', (
      tester,
    ) async {
      await open(tester, Role.officer);
      api.on('POST', '/api/registrations/11/approve', (_) {
        applications.clear();
        return const FakeResponse(400, {'message': 'This application has already been decided.'});
      });
      await tester.tapVisible(find.byKey(const Key('approve')));
      await tester.tap(inDialog('Approve'));
      await tester.pumpAndSettle();

      expect(find.text('This application has already been decided.'), findsOneWidget);
      expect(find.text('Nimal Silva'), findsNothing);
    });

    testWidgets('the profile changes tab shows the current and requested values', (tester) async {
      await open(tester, Role.officer);
      await openProfileChanges(tester);

      expect(find.text('Nimal Silva'), findsOneWidget);
      expect(find.text('nimal · Kandy'), findsOneWidget);
      expect(find.text('Current: old@example.lk'), findsOneWidget);
      expect(find.text('Requested: new@example.lk'), findsOneWidget);
      expect(find.text('Showing Farmer requests in Kandy'), findsOneWidget);
    });

    testWidgets("approving a change asks for the approver's password", (tester) async {
      await open(tester, Role.officer);
      await openProfileChanges(tester);
      await tester.tapVisible(find.byKey(const Key('approve')));

      await tester.tap(find.byKey(const Key('approve-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Password is required'), findsOneWidget);
      expect(api.lastTo('POST', '/api/profile-change-requests/5/approve'), isNull);

      // A wrong password stays in the dialog, on the field.
      api.on(
        'POST',
        '/api/profile-change-requests/5/approve',
        (_) => const FakeResponse(400, {'message': 'Current password is incorrect.'}),
      );
      await tester.enterText(find.byKey(const Key('approve-password')), 'wrong');
      await tester.tap(find.byKey(const Key('approve-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Current password is incorrect.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);

      // The right one approves and reloads the list.
      api.on('POST', '/api/profile-change-requests/5/approve', (_) {
        changes.clear();
        return const FakeResponse(204);
      });
      await tester.enterText(find.byKey(const Key('approve-password')), 'right');
      await tester.tap(find.byKey(const Key('approve-confirm')));
      await tester.pumpAndSettle();

      expect(api.lastTo('POST', '/api/profile-change-requests/5/approve')!.json, {
        'currentPassword': 'right',
      });
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('The change was approved.'), findsOneWidget);
      expect(find.text('No profile changes are waiting for review right now.'), findsOneWidget);
    });

    testWidgets('a change that was already decided closes the dialog and reloads', (tester) async {
      await open(tester, Role.officer);
      await openProfileChanges(tester);
      await tester.tapVisible(find.byKey(const Key('approve')));

      api.on('POST', '/api/profile-change-requests/5/approve', (_) {
        changes.clear();
        return const FakeResponse(400, {'message': 'This request has already been decided.'});
      });
      await tester.enterText(find.byKey(const Key('approve-password')), 'right');
      await tester.tap(find.byKey(const Key('approve-confirm')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('This request has already been decided.'), findsOneWidget);
      expect(find.text('No profile changes are waiting for review right now.'), findsOneWidget);
    });

    testWidgets('rejecting a change needs a reason', (tester) async {
      await open(tester, Role.officer);
      await openProfileChanges(tester);
      await tester.tapVisible(find.byKey(const Key('reject')));
      await tester.tapVisible(find.byKey(const Key('reject-submit')));
      expect(find.text('Please give a reason.'), findsOneWidget);
      expect(api.lastTo('POST', '/api/profile-change-requests/5/reject'), isNull);

      api.on('POST', '/api/profile-change-requests/5/reject', (_) {
        changes.clear();
        return const FakeResponse(204);
      });
      await tester.fill(find.byKey(const Key('reject-reason')), 'Not the same person');
      await tester.tapVisible(find.byKey(const Key('reject-submit')));

      expect(api.lastTo('POST', '/api/profile-change-requests/5/reject')!.json, {
        'reason': 'Not the same person',
      });
      expect(find.text('The change was rejected.'), findsOneWidget);
    });

    testWidgets('the cards fit a narrow screen in Sinhala', (tester) async {
      applications.add(buyerApplicationJson());
      await open(tester, Role.admin, language: 'si', screen: const Size(320, 640));
      expect(tester.takeException(), isNull);
      expect(find.text('Nimal Silva'), findsOneWidget);
    });
  });
}
