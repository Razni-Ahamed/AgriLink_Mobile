import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'role.dart';
import 'session.dart';

/// Where the session survives an app restart. The token is a credential, so the real
/// implementation uses Android's encrypted storage rather than shared preferences.
abstract interface class SessionStorage {
  Future<Session?> read();
  Future<void> write(Session session);
  Future<void> clear();
}

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'agrilink.session.token';
  static const _roleKey = 'agrilink.session.role';

  @override
  Future<Session?> read() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final role = Role.fromApi(await _storage.read(key: _roleKey));
      if (token == null || token.isEmpty || role == null) {
        return null;
      }
      return Session(token: token, role: role);
    } on PlatformException {
      // Unreadable storage (e.g. keys lost after a backup restore) means signed out.
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(Session session) async {
    await _storage.write(key: _tokenKey, value: session.token);
    await _storage.write(key: _roleKey, value: session.role.apiName);
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _roleKey);
    } on PlatformException {
      // Nothing more can be done; the in-memory session is already cleared.
    }
  }
}

/// Keeps the session in memory only. For tests.
class InMemorySessionStorage implements SessionStorage {
  InMemorySessionStorage([this.session]);

  Session? session;

  @override
  Future<Session?> read() async => session;

  @override
  Future<void> write(Session session) async => this.session = session;

  @override
  Future<void> clear() async => session = null;
}

final sessionStorageProvider = Provider<SessionStorage>((ref) => SecureSessionStorage());
