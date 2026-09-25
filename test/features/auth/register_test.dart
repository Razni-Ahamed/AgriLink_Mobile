import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';

Finder field(String name) => find.byKey(Key('register-$name'));

void main() {
  FakeApi registrationApi() => FakeApi()
    ..on('GET', '/api/districts', (_) => const FakeResponse(200, ['Colombo', 'Kandy', 'Matale']))
    ..on(
      'GET',
      '/api/users/username-available',
      (request) => FakeResponse(200, {
        'available': request.query['username'] != 'taken.name',
        'reason': request.query['username'] == 'taken.name' ? 'taken' : null,
      }),
    );

  Future<TestApp> openRegister(WidgetTester tester, [FakeApi? api]) async {
    final app = await pumpAgriLink(tester, api: api ?? registrationApi());
    await tester.tapVisible(find.text('Register'));
    expect(find.text('Create your account'), findsOneWidget);
    return app;
  }

  Future<void> fillCommon(WidgetTester tester, {String username = 'Kamal.Perera'}) async {
    await tester.fill(field('fullName'), '  Kamal Perera ');
    await tester.fill(field('email'), 'kamal@example.lk');
    await tester.fill(field('username'), username);
    await tester.fill(field('password'), 'Gardening2026!');
    await tester.fill(field('confirmPassword'), 'Gardening2026!');
    await tester.fill(field('nic'), '851234567v');
    await tester.tapVisible(find.text('District'));
    await tester.tap(find.text('Kandy'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the farmer fields, and the buyer fields for a buyer', (tester) async {
    await openRegister(tester);
    expect(field('fieldPlotNumber'), findsOneWidget);
    expect(field('phoneNumber'), findsOneWidget);
    expect(field('legalBusinessName'), findsNothing);

    await tester.tapVisible(find.text('Buyer'));
    expect(field('fieldPlotNumber'), findsNothing);
    expect(field('legalBusinessName'), findsOneWidget);
    expect(field('businessRegistrationNumber'), findsOneWidget);
    expect(field('businessPhone'), findsOneWidget);
  });

  testWidgets('validates like the website before sending', (tester) async {
    final app = await openRegister(tester);
    await tester.fill(field('nic'), '12345');
    await tester.fill(field('password'), 'short');
    await tester.fill(field('phoneNumber'), '0771');
    await tester.tapVisible(field('fieldPlotNumber'));
    await tester.tapVisible(find.byKey(const Key('register-submit')));

    expect(find.text('Full name is required'), findsOneWidget);
    expect(find.text('NIC must be 12 digits, or 9 digits followed by V or X'), findsOneWidget);
    expect(find.text('Password must be at least 12 characters'), findsOneWidget);
    expect(find.text('District is required'), findsOneWidget);
    expect(find.text('Field/plot number is required'), findsOneWidget);
    expect(find.text('Phone number must be 10 digits'), findsOneWidget);
    expect(app.api.lastTo('POST', '/api/auth/register'), isNull);
  });

  testWidgets('the password checklist and username check update while typing', (tester) async {
    await openRegister(tester);
    await tester.fill(field('password'), 'abc');
    expect(tester.getSemantics(find.text('At least 12 characters')).label, contains('not met'));

    await tester.fill(field('username'), 'taken.name');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('That username is taken'), findsOneWidget);

    await tester.fill(field('username'), 'free.name');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Username is available'), findsOneWidget);
  });

  testWidgets('registers a farmer with normalised values and shows the pending screen', (
    tester,
  ) async {
    final api = registrationApi()
      ..on(
        'POST',
        '/api/auth/register',
        (_) => const FakeResponse(201, {
          'message': 'Your application has been submitted and is waiting for approval.',
          'status': 'Pending',
        }),
      );
    final app = await openRegister(tester, api);
    await fillCommon(tester);
    await tester.fill(field('fieldPlotNumber'), ' KD-12 ');
    await tester.fill(field('phoneNumber'), '077 123 4567');
    await tester.tapVisible(find.byKey(const Key('register-submit')));

    expect(app.api.lastTo('POST', '/api/auth/register')!.json, {
      'fullName': 'Kamal Perera',
      'email': 'kamal@example.lk',
      'username': 'kamal.perera',
      'password': 'Gardening2026!',
      'nic': '851234567V',
      'district': 'Kandy',
      'role': 'Farmer',
      'fieldPlotNumber': 'KD-12',
      'phoneNumber': '0771234567',
    });
    expect(find.text('Application submitted'), findsOneWidget);
    expect(app.session.isSignedIn, isFalse);
  });

  testWidgets('registers a buyer with the business fields', (tester) async {
    final api = registrationApi()
      ..on('POST', '/api/auth/register', (_) => const FakeResponse(201, {'status': 'Pending'}));
    final app = await openRegister(tester, api);
    await tester.tapVisible(find.text('Buyer'));
    await fillCommon(tester);
    await tester.fill(field('legalBusinessName'), 'Green Traders (Pvt) Ltd');
    await tester.fill(field('businessRegistrationNumber'), 'PV-1234');
    await tester.fill(field('businessPhone'), '011-234-5678');
    await tester.tapVisible(find.byKey(const Key('register-submit')));

    final body = app.api.lastTo('POST', '/api/auth/register')!.json;
    expect(body['role'], 'Buyer');
    expect(body['legalBusinessName'], 'Green Traders (Pvt) Ltd');
    expect(body['businessPhone'], '0112345678');
    expect(body.containsKey('fieldPlotNumber'), isFalse);
    expect(find.text('Application submitted'), findsOneWidget);
  });

  testWidgets('server validation errors appear under their fields', (tester) async {
    final api = registrationApi()
      ..on(
        'POST',
        '/api/auth/register',
        (_) => const FakeResponse(400, {
          'title': 'One or more validation errors occurred.',
          'errors': {
            'Email': ['The Email field is not a valid e-mail address.'],
            'PhoneNumber': ['The field PhoneNumber must be at most 20 characters.'],
          },
        }),
      );
    await openRegister(tester, api);
    await fillCommon(tester);
    await tester.fill(field('fieldPlotNumber'), 'KD-12');
    await tester.fill(field('phoneNumber'), '0771234567');
    await tester.tapVisible(find.byKey(const Key('register-submit')));

    expect(find.text('The Email field is not a valid e-mail address.'), findsOneWidget);
    expect(find.text('The field PhoneNumber must be at most 20 characters.'), findsOneWidget);

    // Editing the field clears its server error.
    await tester.fill(field('email'), 'kamal2@example.lk');
    expect(find.text('The Email field is not a valid e-mail address.'), findsNothing);
  });

  testWidgets('an email that already exists and a taken username are explained', (tester) async {
    var response = const FakeResponse(409, {
      'message': 'An account with this email already exists.',
    });
    final api = registrationApi()..on('POST', '/api/auth/register', (_) => response);
    await openRegister(tester, api);
    await fillCommon(tester);
    await tester.fill(field('fieldPlotNumber'), 'KD-12');
    await tester.fill(field('phoneNumber'), '0771234567');
    await tester.tapVisible(find.byKey(const Key('register-submit')));
    expect(find.text('An account with this email already exists.'), findsOneWidget);

    response = const FakeResponse(409, {
      'errors': [
        {'code': 'DuplicateUserName', 'description': 'That username is taken.'},
      ],
    });
    await tester.tapVisible(find.byKey(const Key('register-submit')));
    expect(find.text('That username is taken.'), findsOneWidget);
  });

  testWidgets('a weak password rejected by the server uses the checklist wording', (tester) async {
    final api = registrationApi()
      ..on(
        'POST',
        '/api/auth/register',
        (_) => const FakeResponse(400, {
          'errors': [
            {'code': 'PasswordRequiresNonAlphanumeric', 'description': 'Passwords must have…'},
          ],
        }),
      );
    await openRegister(tester, api);
    await fillCommon(tester);
    await tester.fill(field('fieldPlotNumber'), 'KD-12');
    await tester.fill(field('phoneNumber'), '0771234567');
    await tester.tapVisible(find.byKey(const Key('register-submit')));
    expect(find.text('Password must include a symbol'), findsOneWidget);
  });
}
