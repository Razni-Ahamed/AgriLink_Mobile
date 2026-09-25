import 'dart:convert';

import 'role.dart';

/// A signed-in session: the JWT and the role the login returned.
class Session {
  const Session({required this.token, required this.role});

  final String token;
  final Role role;

  /// When the token stops being accepted, read from its `exp` claim. Tokens last 8 hours and
  /// there is no refresh token, so the user signs in again after this. Null if unreadable.
  DateTime? get expiresAt {
    final parts = token.split('.');
    if (parts.length != 3) {
      return null;
    }
    try {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final exp = payload is Map ? payload['exp'] : null;
      return exp is num
          ? DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true)
          : null;
    } on FormatException {
      return null;
    }
  }

  bool isExpired([DateTime? now]) {
    final expiry = expiresAt;
    return expiry != null && !(now ?? DateTime.now()).toUtc().isBefore(expiry);
  }

  @override
  bool operator ==(Object other) => other is Session && other.token == token && other.role == role;

  @override
  int get hashCode => Object.hash(token, role);
}
