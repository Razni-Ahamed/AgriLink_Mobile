import 'dart:async';

import 'package:agrilink_mobile/app/router/app_router.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';

/// A fake API with what every signed-in marketplace screen needs: the profile (the farmer's
/// `farmerProfileId` is 7), the unread count and the districts.
FakeApi marketplaceFakeApi(Role role) => FakeApi()
  ..on('GET', '/api/users/me', (_) => FakeResponse(200, profileJson(role)))
  ..on('GET', '/api/notifications/unread-count', (_) => const FakeResponse(200, {'count': 0}))
  ..on('GET', '/api/districts', (_) => const FakeResponse(200, ['Colombo', 'Kandy', 'Kurunegala']));

/// Starts the app signed in as [role] and opens [path].
Future<TestApp> pumpMarketplace(
  WidgetTester tester, {
  required Role role,
  required FakeApi api,
  required String path,
  String language = 'en',
}) async {
  final app = await pumpAgriLink(
    tester,
    api: api,
    session: Session(token: fakeJwt(), role: role),
    language: language,
  );
  app.container.read(routerProvider).go(path);
  await tester.pumpAndSettle();
  return app;
}

/// Opens [path] on top of the current page, as tapping a card does.
Future<void> pushPath(TestApp app, String path) async {
  // push completes only when the page is closed, so don't wait for it here.
  unawaited(app.container.read(routerProvider).push(path));
  await app.tester.pumpAndSettle();
}
