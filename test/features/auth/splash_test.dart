import 'package:agrilink_mobile/app/router/app_router.dart';
import 'package:agrilink_mobile/app/router/app_routes.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:agrilink_mobile/core/session/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';

void main() {
  group('redirectFor', () {
    const restoring = SessionState.restoring();
    const signedOut = SessionState.signedOut();
    const farmer = SessionState.signedIn(Session(token: 't', role: Role.farmer));

    test('waits on the splash screen while restoring', () {
      expect(redirectFor(restoring, AppRoutes.farms), AppRoutes.splash);
      expect(redirectFor(restoring, AppRoutes.splash), isNull);
    });

    test('keeps a signed-out user on the public screens', () {
      expect(redirectFor(signedOut, AppRoutes.farms), AppRoutes.login);
      expect(redirectFor(signedOut, AppRoutes.splash), AppRoutes.login);
      expect(redirectFor(signedOut, AppRoutes.register), isNull);
      expect(redirectFor(signedOut, AppRoutes.registerPending), isNull);
    });

    test('sends a signed-in user from the public screens to their home', () {
      expect(redirectFor(farmer, AppRoutes.login), AppRoutes.farms);
      expect(redirectFor(farmer, AppRoutes.register), AppRoutes.farms);
      expect(redirectFor(farmer, AppRoutes.splash), isNull);
    });
  });

  testWidgets('restores a stored session and loads the profile', (tester) async {
    final api = FakeApi()
      ..on('GET', '/api/users/me', (_) => FakeResponse(200, profileJson(Role.buyer)));
    final token = fakeJwt();
    final app = await pumpAgriLink(
      tester,
      api: api,
      session: Session(token: token, role: Role.buyer),
    );
    expect(app.session.role, Role.buyer);
    expect(api.lastTo('GET', '/api/users/me')!.headers['Authorization'], 'Bearer $token');
    expect(find.text('Sign in to your account'), findsNothing);
  });

  testWidgets('a token the server rejects ends the session', (tester) async {
    final api = FakeApi()..on('GET', '/api/users/me', (_) => const FakeResponse(401));
    final app = await pumpAgriLink(
      tester,
      api: api,
      session: Session(token: fakeJwt(), role: Role.farmer),
    );
    expect(app.session.status, SessionStatus.signedOut);
    expect(app.storage.session, isNull);
    expect(find.text('Your session has ended. Please sign in again.'), findsOneWidget);
  });

  testWidgets('no connection at start-up offers a retry, keeping the session', (tester) async {
    final api = FakeApi()..offline('GET', '/api/users/me');
    final app = await pumpAgriLink(
      tester,
      api: api,
      session: Session(token: fakeJwt(), role: Role.farmer),
    );
    expect(find.textContaining("Can't reach the server"), findsOneWidget);
    expect(app.storage.session, isNotNull);

    api.on('GET', '/api/users/me', (_) => FakeResponse(200, profileJson(Role.farmer)));
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Can't reach the server"), findsNothing);
    expect(app.session.isSignedIn, isTrue);
  });
}
