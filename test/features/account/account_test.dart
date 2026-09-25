import 'dart:typed_data';

import 'package:agrilink_mobile/app/router/app_router.dart';
import 'package:agrilink_mobile/app/router/app_routes.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:agrilink_mobile/shared/media/photo_picker.dart';
import 'package:agrilink_mobile/shared/permissions/permissions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';

class FakePhotoPicker implements PhotoPicker {
  final List<PhotoSource> picked = [];

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    picked.add(source);
    // A 1×1 transparent PNG stands in for the compressed JPEG.
    return PickedPhoto(
      Uint8List.fromList(const [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, //
        0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00,
        0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78,
        0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]),
    );
  }
}

class FakePermissions implements PermissionService {
  FakePermissions(this.result);

  PermissionResult result;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<PermissionResult> status(AppPermission permission) async => result;

  @override
  Future<PermissionResult> request(AppPermission permission) async {
    requests++;
    return result;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

Map<String, Object?> securityJson({
  List<String> canChange = const ['password', 'phone'],
  List<String> canRequest = const ['fullName', 'nic', 'email'],
  List<Map<String, Object?>> requests = const [],
}) => {
  'canChange': canChange,
  'canRequest': canRequest,
  'phoneNumber': '0771234567',
  'nic': '851234567V',
  'changeRequests': requests,
};

void main() {
  late FakeApi api;
  late FakePhotoPicker photos;
  late FakePermissions permissions;

  setUp(() {
    api = FakeApi();
    photos = FakePhotoPicker();
    permissions = FakePermissions(PermissionResult.granted);
  });

  Future<TestApp> openProfile(
    WidgetTester tester,
    Role role, {
    Map<String, Object?>? profile,
  }) async {
    api.on('GET', '/api/users/me', (_) => FakeResponse(200, profile ?? profileJson(role)));
    final app = await pumpAgriLink(
      tester,
      api: api,
      session: Session(token: fakeJwt(), role: role),
      overrides: [
        photoPickerProvider.overrideWithValue(photos),
        permissionServiceProvider.overrideWithValue(permissions),
      ],
    );
    await tester.tap(find.byKey(const Key('avatar-button')));
    await tester.pumpAndSettle();
    return app;
  }

  String currentPath(TestApp app) =>
      app.container.read(routerProvider).routerDelegate.currentConfiguration.uri.path;

  group('profile', () {
    testWidgets("shows a farmer's details and where to change them", (tester) async {
      await openProfile(tester, Role.farmer);
      expect(find.text('My profile'), findsOneWidget);
      expect(find.text('Kamal Perera'), findsWidgets);
      expect(find.text('@kamal'), findsWidgets);
      expect(find.text('KD-12'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('851234567V'), 200);
      expect(find.text('851234567V'), findsOneWidget);
      expect(find.text('Requires approval — request this in Security settings.'), findsWidgets);
      expect(find.text('Agriculture'), findsNothing);
    });

    testWidgets("shows an officer's department", (tester) async {
      await openProfile(tester, Role.officer);
      await tester.scrollUntilVisible(find.text('Agriculture'), 200);
      expect(find.text('Agriculture'), findsOneWidget);
      expect(find.text('KD-12'), findsNothing);
    });

    testWidgets('logging out asks first, then clears the session', (tester) async {
      final app = await openProfile(tester, Role.buyer);
      await tester.tapVisible(find.byKey(const Key('sign-out')));
      expect(find.text('Log out of AgriLink?'), findsOneWidget);
      await tester.tap(find.text('Log out').last);
      await tester.pumpAndSettle();

      expect(app.session.isSignedIn, isFalse);
      expect(app.storage.session, isNull);
      expect(find.text('Sign in to your account'), findsOneWidget);
    });
  });

  group('edit profile', () {
    testWidgets('sends only the changed fields', (tester) async {
      api
        ..on(
          'GET',
          '/api/users/username-available',
          (_) => const FakeResponse(200, {'available': true}),
        )
        ..on('PUT', '/api/users/me/profile', (request) {
          final updated = {...profileJson(Role.farmer), ...request.json};
          return FakeResponse(200, updated);
        });
      final app = await openProfile(tester, Role.farmer);
      await tester.tapVisible(find.byKey(const Key('edit-profile')));

      await tester.fill(find.byKey(const Key('edit-displayName')), 'Kamal');
      await tester.fill(find.byKey(const Key('edit-username')), 'Kamal.P');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tapVisible(find.byKey(const Key('save-profile')));

      expect(app.api.lastTo('PUT', '/api/users/me/profile')!.json, {
        'displayName': 'Kamal',
        'username': 'kamal.p',
      });
      expect(find.text('Your profile has been updated.'), findsOneWidget);
      expect(currentPath(app), AppRoutes.profile);
    });

    testWidgets('a locked username cannot be edited', (tester) async {
      await openProfile(
        tester,
        Role.buyer,
        profile: {
          ...profileJson(Role.buyer),
          'usernameChangeAvailableAt': DateTime.now()
              .add(const Duration(days: 12))
              .toUtc()
              .toIso8601String(),
        },
      );
      await tester.tapVisible(find.byKey(const Key('edit-profile')));
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('edit-username')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.enabled, isFalse);
      expect(find.textContaining('You can change your username again on'), findsOneWidget);
    });

    testWidgets('uploads a new photo when saving', (tester) async {
      api.on(
        'POST',
        '/api/users/me/photo',
        (_) => FakeResponse(200, {
          ...profileJson(Role.farmer),
          'profilePhotoUrl': 'https://res.cloudinary.com/demo/a.jpg',
        }),
      );
      final app = await openProfile(tester, Role.farmer);
      await tester.tapVisible(find.byKey(const Key('edit-profile')));
      await tester.tapVisible(find.byKey(const Key('change-photo')));
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();

      expect(photos.picked, [PhotoSource.gallery]);
      expect(find.text('New photo — saved when you choose Update profile.'), findsOneWidget);
      await tester.tapVisible(find.byKey(const Key('save-profile')));

      final upload = app.api.lastTo('POST', '/api/users/me/photo')!;
      final form = upload.body! as FormData;
      expect(form.files.single.key, 'photo');
      expect(form.files.single.value.contentType.toString(), 'image/jpeg');
      expect(app.api.lastTo('PUT', '/api/users/me/profile'), isNull);
    });

    testWidgets('the camera is only used after asking, and a blocked camera offers settings', (
      tester,
    ) async {
      permissions.result = PermissionResult.permanentlyDenied;
      await openProfile(tester, Role.farmer);
      await tester.tapVisible(find.byKey(const Key('edit-profile')));
      await tester.tapVisible(find.byKey(const Key('change-photo')));
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Camera access is turned off for AgriLink'), findsOneWidget);
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(permissions.settingsOpened, 1);
      expect(photos.picked, isEmpty);
    });

    testWidgets('the camera explains itself before Android asks', (tester) async {
      permissions.result = PermissionResult.denied;
      await openProfile(tester, Role.farmer);
      await tester.tapVisible(find.byKey(const Key('edit-profile')));
      await tester.tapVisible(find.byKey(const Key('change-photo')));
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();

      expect(find.text('Allow camera access'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(permissions.requests, 0);
      expect(photos.picked, isEmpty);
    });
  });

  group('security', () {
    Future<TestApp> openSecurity(
      WidgetTester tester,
      Role role, {
      Map<String, Object?>? security,
      FakeResponse Function(RecordedRequest request)? securityHandler,
    }) async {
      api.on(
        'GET',
        '/api/users/me/security',
        securityHandler ?? (_) => FakeResponse(200, security ?? securityJson()),
      );
      final app = await openProfile(tester, role);
      await tester.tapVisible(find.byKey(const Key('security-settings')));
      return app;
    }

    Future<void> unlock(WidgetTester tester, {String password = 'Gardening2026!'}) async {
      await tester.tapVisible(find.byKey(const Key('unlock-security')));
      await tester.fill(find.byKey(const Key('unlock-password')), password);
      await tester.tapVisible(find.byKey(const Key('unlock-submit')));
    }

    testWidgets('a wrong password keeps it locked, and does not sign out', (tester) async {
      api.on(
        'POST',
        '/api/users/me/verify-password',
        (_) => const FakeResponse(400, {'message': 'Current password is incorrect.'}),
      );
      final app = await openSecurity(tester, Role.farmer);
      await unlock(tester, password: 'wrong');
      expect(find.text('Current password is incorrect.'), findsOneWidget);
      expect(find.byKey(const Key('current-password')), findsNothing);
      expect(app.session.isSignedIn, isTrue);
    });

    testWidgets('changing the password stores the new token', (tester) async {
      final newToken = fakeJwt(subject: 'rotated');
      api
        ..on('POST', '/api/users/me/verify-password', (_) => const FakeResponse(200))
        ..on(
          'POST',
          '/api/users/me/password',
          (_) => FakeResponse(200, {'token': newToken, 'role': 'Farmer'}),
        );
      final app = await openSecurity(tester, Role.farmer);
      await unlock(tester);

      await tester.fill(find.byKey(const Key('current-password')), 'Gardening2026!');
      await tester.fill(find.byKey(const Key('new-password')), 'Harvesting2027!');
      await tester.fill(find.byKey(const Key('confirm-new-password')), 'Harvesting2027!');
      await tester.tapVisible(find.byKey(const Key('change-password-submit')));

      expect(app.api.lastTo('POST', '/api/users/me/password')!.json, {
        'currentPassword': 'Gardening2026!',
        'newPassword': 'Harvesting2027!',
      });
      expect(app.session.token, newToken);
      expect(app.storage.session?.token, newToken);
      expect(find.text('Your password has been changed.'), findsOneWidget);

      // The next request uses the new token.
      await tester.tapVisible(find.byKey(const Key('avatar-button')));
      await tester.pumpAndSettle();
      expect(app.api.lastTo('GET', '/api/users/me')!.headers['Authorization'], 'Bearer $newToken');
    });

    testWidgets('a farmer requests a NIC change and can withdraw it', (tester) async {
      var requests = <Map<String, Object?>>[];
      api
        ..on('POST', '/api/users/me/verify-password', (_) => const FakeResponse(200))
        ..on('POST', '/api/users/me/change-requests', (request) {
          final created = {
            'requestId': 5,
            'field': request.json['field'],
            'oldValue': '851234567V',
            'newValue': request.json['newValue'],
            'status': 'Pending',
            'requestedAt': '2026-09-25T10:00:00Z',
          };
          requests = [created];
          return FakeResponse(201, created);
        })
        ..on('DELETE', '/api/users/me/change-requests/5', (_) {
          requests = [];
          return const FakeResponse(204);
        });
      final app = await openSecurity(
        tester,
        Role.farmer,
        securityHandler: (_) => FakeResponse(200, securityJson(requests: requests)),
      );
      await unlock(tester);

      await tester.fill(find.byKey(const Key('security-input-NIC')), '200012345678');
      await tester.tapVisible(find.byKey(const Key('security-submit-NIC')));

      expect(app.api.lastTo('POST', '/api/users/me/change-requests')!.json, {
        'currentPassword': 'Gardening2026!',
        'field': 'NIC',
        'newValue': '200012345678',
      });
      expect(find.text('Your request was submitted for approval.'), findsOneWidget);
      expect(find.text('Pending approval'), findsOneWidget);
      expect(find.text('Requested: 200012345678'), findsOneWidget);

      await tester.tapVisible(find.text('Withdraw'));
      expect(app.api.lastTo('DELETE', '/api/users/me/change-requests/5'), isNotNull);
      expect(find.text('Pending approval'), findsNothing);
    });

    testWidgets('the phone number saves directly', (tester) async {
      api
        ..on('POST', '/api/users/me/verify-password', (_) => const FakeResponse(200))
        ..on(
          'PUT',
          '/api/users/me/phone',
          (_) => FakeResponse(200, {...profileJson(Role.buyer), 'phoneNumber': '0719876543'}),
        );
      final app = await openSecurity(tester, Role.buyer);
      await unlock(tester);
      await tester.fill(find.byKey(const Key('security-input-Phone number')), '071 987 6543');
      await tester.tapVisible(find.byKey(const Key('security-submit-Phone number')));

      expect(app.api.lastTo('PUT', '/api/users/me/phone')!.json, {
        'currentPassword': 'Gardening2026!',
        'phoneNumber': '0719876543',
      });
      expect(find.text('Your phone number was updated.'), findsOneWidget);
    });

    testWidgets('an officer has no NIC row; an admin changes the name directly', (tester) async {
      await openSecurity(
        tester,
        Role.admin,
        security: securityJson(
          canChange: ['password', 'phone', 'fullName', 'email'],
          canRequest: [],
        ),
      );
      expect(find.text('NIC'), findsNothing);
      api.on('POST', '/api/users/me/verify-password', (_) => const FakeResponse(200));
      await unlock(tester);
      expect(find.text('Submit for approval'), findsNothing);
      expect(find.text('Save'), findsNWidgets(3));
    });

    testWidgets('a rejected request shows its reason', (tester) async {
      await openSecurity(
        tester,
        Role.farmer,
        security: securityJson(
          requests: [
            {
              'requestId': 3,
              'field': 'FullName',
              'oldValue': 'Kamal Perera',
              'newValue': 'K. Perera',
              'status': 'Rejected',
              'requestedAt': '2026-09-01T10:00:00Z',
              'decidedAt': '2026-09-02T10:00:00Z',
              'rejectionReason': 'Please use your full legal name.',
            },
          ],
        ),
      );
      expect(find.textContaining('Reason: Please use your full legal name.'), findsOneWidget);
    });
  });
}
