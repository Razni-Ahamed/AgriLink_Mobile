import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:agrilink_mobile/core/session/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';

void main() {
  final email = find.byKey(const Key('login-email'));
  final password = find.byKey(const Key('login-password'));
  final submit = find.byKey(const Key('login-submit'));

  Future<TestApp> signIn(
    WidgetTester tester,
    FakeResponse Function(RecordedRequest request) response,
  ) async {
    final api = FakeApi()..on('POST', '/api/auth/login', response);
    final app = await pumpAgriLink(tester, api: api);
    await tester.fill(email, ' kamal@example.lk ');
    await tester.fill(password, 'Gardening2026!');
    await tester.tapVisible(submit);
    return app;
  }

  testWidgets('starts on the login screen with no stored session', (tester) async {
    await pumpAgriLink(tester);
    expect(find.text('Sign in to your account'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('checks the form before sending anything', (tester) async {
    final app = await pumpAgriLink(tester);
    await tester.tapVisible(submit);
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(app.api.requests, isEmpty);
  });

  testWidgets('signs in and goes to the role home', (tester) async {
    final token = fakeJwt();
    final app = await signIn(tester, (_) => FakeResponse(200, {'token': token, 'role': 'Officer'}));
    app.api.on('GET', '/api/users/me', (_) => FakeResponse(200, profileJson(Role.officer)));
    await tester.pumpAndSettle();

    final request = app.api.lastTo('POST', '/api/auth/login')!;
    expect(request.json, {'email': 'kamal@example.lk', 'password': 'Gardening2026!'});
    expect(app.session.status, SessionStatus.signedIn);
    expect(app.session.role, Role.officer);
    expect(app.storage.session?.token, token);
    expect(find.text('Sign in to your account'), findsNothing);
  });

  testWidgets('a wrong password shows the website message', (tester) async {
    final app = await signIn(
      tester,
      (_) => const FakeResponse(401, {'message': 'Invalid email or password.'}),
    );
    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(app.session.isSignedIn, isFalse);
  });

  testWidgets('a pending account is told it is waiting for approval', (tester) async {
    await signIn(
      tester,
      (_) => const FakeResponse(403, {'message': 'Your account is waiting for approval.'}),
    );
    expect(find.text('Waiting for approval'), findsOneWidget);
    expect(find.textContaining('You can sign in once'), findsOneWidget);
  });

  testWidgets('a rejected registration shows the reason', (tester) async {
    await signIn(
      tester,
      (_) => const FakeResponse(403, {
        'message': 'Your registration was not approved.',
        'reason': 'The plot number could not be verified.',
      }),
    );
    expect(find.text('Registration not approved'), findsOneWidget);
    expect(find.text('Reason: The plot number could not be verified.'), findsOneWidget);
  });

  testWidgets('a rejected registration without a reason still explains', (tester) async {
    await signIn(
      tester,
      (_) => const FakeResponse(403, {
        'message': 'Your registration was not approved.',
        'reason': null,
      }),
    );
    expect(find.text('Your registration was not approved.'), findsOneWidget);
    expect(find.textContaining('Reason:'), findsNothing);
  });

  testWidgets('no connection shows a friendly message and a retry', (tester) async {
    final api = FakeApi()..offline('POST', '/api/auth/login');
    final app = await pumpAgriLink(tester, api: api);
    await tester.fill(email, 'kamal@example.lk');
    await tester.fill(password, 'Gardening2026!');
    await tester.tapVisible(submit);

    expect(find.textContaining("Can't reach the server"), findsOneWidget);
    final token = fakeJwt();
    app.api
      ..on('POST', '/api/auth/login', (_) => FakeResponse(200, {'token': token, 'role': 'Buyer'}))
      ..on('GET', '/api/users/me', (_) => FakeResponse(200, profileJson(Role.buyer)));
    await tester.tapVisible(find.text('Try again'));
    expect(app.session.role, Role.buyer);
  });

  testWidgets('an expired stored session says the session has ended', (tester) async {
    final expired = Session(
      token: fakeJwt(expiresAt: DateTime.now().subtract(const Duration(minutes: 5))),
      role: Role.farmer,
    );
    final app = await pumpAgriLink(tester, session: expired);
    expect(find.text('Your session has ended. Please sign in again.'), findsOneWidget);
    expect(app.storage.session, isNull);
  });

  testWidgets('the screen is translated', (tester) async {
    await pumpAgriLink(tester, language: 'ta');
    expect(find.text('உங்கள் கணக்கில் உள்நுழையவும்'), findsOneWidget);
  });
}
