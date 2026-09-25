import 'dart:convert';

import 'package:agrilink_mobile/app/app.dart';
import 'package:agrilink_mobile/core/api/api_client.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:agrilink_mobile/core/session/session_controller.dart';
import 'package:agrilink_mobile/core/session/session_storage.dart';
import 'package:agrilink_mobile/core/storage/preferences.dart';
import 'package:agrilink_mobile/features/notifications/application/notification_presenter.dart';
import 'package:agrilink_mobile/shared/permissions/permissions.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';
import 'fakes.dart';

/// A JWT-shaped token expiring at [expiresAt] (8 hours from now by default). Unsigned: the app
/// never checks signatures, only the expiry.
String fakeJwt({DateTime? expiresAt, String subject = '1'}) {
  String part(Object json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final expiry = expiresAt ?? DateTime.now().add(const Duration(hours: 8));
  return '${part({'alg': 'HS256'})}'
      '.${part({'sub': subject, 'exp': expiry.millisecondsSinceEpoch ~/ 1000})}'
      '.signature';
}

/// A `/api/users/me` body for [role].
Map<String, Object?> profileJson(Role role, {String name = 'Kamal Perera'}) => {
  'userId': 1,
  'fullName': name,
  'email': 'kamal@example.lk',
  'role': role.apiName,
  'username': 'kamal',
  'displayName': null,
  'profilePhotoUrl': null,
  'nic': '851234567V',
  'district': 'Kandy',
  'phoneNumber': '0771234567',
  'fieldPlotNumber': role == Role.farmer ? 'KD-12' : null,
  'businessName': role == Role.buyer ? 'Green Traders' : null,
  'businessRegistrationNumber': role == Role.buyer ? 'PV-1234' : null,
  'departmentName': role == Role.officer ? 'Agriculture' : null,
  'usernameChangeAvailableAt': null,
  'createdAt': '2026-01-15T08:30:00Z',
  'farmerProfileId': role == Role.farmer ? 7 : null,
};

/// The running test app: the fake API, the stored session and the provider container.
class TestApp {
  TestApp(this.api, this.storage, this.tester, this.permissions, this.presenter);

  final FakeApi api;
  final InMemorySessionStorage storage;
  final WidgetTester tester;
  final FakePermissions permissions;
  final FakePresenter presenter;

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(AgriLinkApp)));

  SessionState get session => container.read(sessionControllerProvider);
}

/// Starts the whole app (router, theme, translations) against [api], with an optional stored
/// [session] (as if the user signed in earlier) and a phone-sized screen.
Future<TestApp> pumpAgriLink(
  WidgetTester tester, {
  FakeApi? api,
  Session? session,
  String language = 'en',
  List<Override> overrides = const [],
  Size screen = const Size(390, 844),
  FakePermissions? permissions,
  FakePresenter? presenter,
  Map<String, Object> preferences = const {},
}) async {
  final fake = api ?? FakeApi();
  final fakePermissions = permissions ?? FakePermissions();
  final fakePresenter = presenter ?? FakePresenter();
  final storage = InMemorySessionStorage(session);
  SharedPreferences.setMockInitialValues({
    PrefKeys.locale: language,
    // Tests of the notification prompt clear this.
    PrefKeys.notificationPermissionAsked: true,
    ...preferences,
  });
  final sharedPreferences = await SharedPreferences.getInstance();

  tester.view.physicalSize = screen * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        sessionStorageProvider.overrideWithValue(storage),
        permissionServiceProvider.overrideWithValue(fakePermissions),
        notificationPresenterProvider.overrideWithValue(fakePresenter),
        apiClientProvider.overrideWith(
          (ref) => fakeApiClient(
            fake,
            readToken: () => ref.read(sessionControllerProvider).token,
            onUnauthorized: (token) =>
                ref.read(sessionControllerProvider.notifier).handleUnauthorized(token),
          ),
        ),
        ...overrides,
      ],
      child: const AgriLinkApp(),
    ),
  );
  await tester.pumpAndSettle();
  return TestApp(fake, storage, tester, fakePermissions, fakePresenter);
}

extension FormHelpers on WidgetTester {
  /// Scrolls until [finder] is built and on screen. Lists build their items lazily, so an item
  /// further down doesn't exist until the list scrolls to it.
  Future<void> reveal(Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await scrollUntilVisible(finder, 150);
    }
    await ensureVisible(finder);
    await pumpAndSettle();
  }

  /// Scrolls [finder] into view and types into it.
  Future<void> fill(Finder finder, String text) async {
    await reveal(finder);
    await enterText(finder, text);
    await pump();
  }

  /// Scrolls [finder] into view, taps it and waits for everything to settle.
  Future<void> tapVisible(Finder finder) async {
    await reveal(finder);
    await tap(finder);
    await pumpAndSettle();
  }
}
