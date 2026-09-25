import 'dart:convert';

import 'package:agrilink_mobile/core/format/formatters.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:agrilink_mobile/core/session/session_controller.dart';
import 'package:agrilink_mobile/core/session/session_storage.dart';
import 'package:agrilink_mobile/l10n/l10n.dart';
import 'package:agrilink_mobile/l10n/locale_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// A JWT-shaped token that expires at [expiresAt]. Not signed; the app never checks signatures.
String fakeJwt(DateTime expiresAt) {
  String part(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'exp': expiresAt.millisecondsSinceEpoch ~/ 1000})}.sig';
}

void main() {
  group('Session', () {
    test('reads the expiry from the token', () {
      final expiry = DateTime.utc(2026, 9, 25, 18);
      final session = Session(token: fakeJwt(expiry), role: Role.farmer);
      expect(session.expiresAt, expiry);
      expect(session.isExpired(DateTime.utc(2026, 9, 25, 17, 59)), isFalse);
      expect(session.isExpired(DateTime.utc(2026, 9, 25, 18)), isTrue);
    });

    test('a token it cannot read never counts as expired', () {
      const session = Session(token: 'not-a-jwt', role: Role.buyer);
      expect(session.expiresAt, isNull);
      expect(session.isExpired(), isFalse);
    });

    test('roles map from the API names', () {
      expect(Role.fromApi('Officer'), Role.officer);
      expect(Role.fromApi('officer'), isNull);
    });
  });

  group('SessionController', () {
    ProviderContainer containerWith(InMemorySessionStorage storage) {
      final container = ProviderContainer(
        overrides: [sessionStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('restores a stored session', () async {
      final session = Session(
        token: fakeJwt(DateTime.now().add(const Duration(hours: 2))),
        role: Role.officer,
      );
      final container = containerWith(InMemorySessionStorage(session));
      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.restoring,
      );

      await container.read(sessionControllerProvider.notifier).restore();
      final state = container.read(sessionControllerProvider);
      expect(state.status, SessionStatus.signedIn);
      expect(state.role, Role.officer);
    });

    test('drops an expired token with the session-ended reason', () async {
      final storage = InMemorySessionStorage(
        Session(
          token: fakeJwt(DateTime.now().subtract(const Duration(minutes: 1))),
          role: Role.farmer,
        ),
      );
      final container = containerWith(storage);
      await container.read(sessionControllerProvider.notifier).restore();

      final state = container.read(sessionControllerProvider);
      expect(state.status, SessionStatus.signedOut);
      expect(state.signOutReason, SignOutReason.sessionExpired);
      expect(storage.session, isNull);
    });

    test('a 401 ends only the session that made the request', () async {
      final storage = InMemorySessionStorage();
      final container = containerWith(storage);
      final controller = container.read(sessionControllerProvider.notifier);
      await controller.signIn(const Session(token: 'new', role: Role.farmer));

      await controller.handleUnauthorized('old');
      expect(container.read(sessionControllerProvider).isSignedIn, isTrue);

      await controller.handleUnauthorized('new');
      final state = container.read(sessionControllerProvider);
      expect(state.isSignedIn, isFalse);
      expect(state.signOutReason, SignOutReason.sessionExpired);
      expect(storage.session, isNull);
    });

    test('signing out clears storage', () async {
      final storage = InMemorySessionStorage();
      final container = containerWith(storage);
      final controller = container.read(sessionControllerProvider.notifier);
      await controller.signIn(const Session(token: 't', role: Role.admin));
      expect(storage.session?.role, Role.admin);

      await controller.signOut();
      expect(storage.session, isNull);
      expect(
        container.read(sessionControllerProvider).signOutReason,
        SignOutReason.userRequested,
      );
    });
  });

  group('Formatters', () {
    setUpAll(initializeDateFormatting);
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('format numbers and prices like the website', () {
      final format = Formatters(AppLanguage.en);
      expect(format.number(1250.5), '1,250.5');
      expect(format.number(1250.456), '1,250.46');
      expect(format.rupees(l10n, 1500), 'Rs 1,500');
      expect(format.rupeesPerUnit(l10n, 85.5), 'Rs 85.5/unit');
      expect(format.kilograms(l10n, 12), '12 kg');
    });

    test('format dates in each language', () {
      final day = DateTime(2026, 9, 25, 15, 40);
      expect(Formatters(AppLanguage.en).date(day), contains('2026'));
      expect(Formatters(AppLanguage.en).date(day), contains('25'));
      for (final language in AppLanguage.values) {
        expect(Formatters(language).date(day), isNotEmpty);
        expect(Formatters(language).dateTime(day), isNotEmpty);
      }
    });
  });
}
