import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'role.dart';
import 'session.dart';
import 'session_storage.dart';

enum SessionStatus {
  /// Reading the stored session at start-up. The splash screen is shown.
  restoring,
  signedOut,
  signedIn,
}

/// Why the user was signed out, so the login screen can say so.
enum SignOutReason {
  /// The user chose "Log out".
  userRequested,

  /// The token expired or the server rejected it (a 401).
  sessionExpired,
}

class SessionState {
  const SessionState._(this.status, this.session, this.signOutReason);

  const SessionState.restoring() : this._(SessionStatus.restoring, null, null);
  const SessionState.signedOut([SignOutReason? reason])
    : this._(SessionStatus.signedOut, null, reason);
  const SessionState.signedIn(Session session) : this._(SessionStatus.signedIn, session, null);

  final SessionStatus status;
  final Session? session;
  final SignOutReason? signOutReason;

  Role? get role => session?.role;
  String? get token => session?.token;
  bool get isSignedIn => status == SessionStatus.signedIn;
}

/// The one source of truth for "who is signed in". The router redirects on it, the API client
/// reads the token from it, and a 401 from any request ends it.
///
/// It knows nothing about screens or the profile: `features/auth` builds sign-in, the current
/// user and sign-out on top of it.
final sessionControllerProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// The current token, or null when signed out.
///
/// Any provider that loads or caches the signed-in user's data must `ref.watch` this, so it
/// is thrown away on sign-out and never shown to the next person who signs in on the phone:
///
/// ```dart
/// final myFarmsProvider = FutureProvider((ref) {
///   ref.watch(sessionTokenProvider);
///   return ref.watch(farmsApiProvider).mine();
/// });
/// ```
final sessionTokenProvider = Provider<String?>(
  (ref) => ref.watch(sessionControllerProvider.select((s) => s.token)),
);

class SessionController extends Notifier<SessionState> {
  SessionStorage get _storage => ref.read(sessionStorageProvider);

  @override
  SessionState build() => const SessionState.restoring();

  /// Loads the stored session at start-up. An expired token is dropped straight away, with
  /// the "session ended" message, rather than waiting for the server to refuse it.
  Future<void> restore() async {
    final stored = await _storage.read();
    if (stored == null) {
      state = const SessionState.signedOut();
    } else if (stored.isExpired()) {
      await _storage.clear();
      state = const SessionState.signedOut(SignOutReason.sessionExpired);
    } else {
      state = SessionState.signedIn(stored);
    }
  }

  /// After a successful login, or when a password change returns a new token.
  Future<void> signIn(Session session) async {
    await _storage.write(session);
    state = SessionState.signedIn(session);
  }

  Future<void> signOut([SignOutReason reason = SignOutReason.userRequested]) async {
    await _storage.clear();
    state = SessionState.signedOut(reason);
  }

  /// Called by the API client on a 401. Only the session that made the request is ended, so
  /// a late 401 for an old token can't sign out a session that has since replaced it.
  Future<void> handleUnauthorized(String? requestToken) async {
    final current = state.session;
    if (current != null && requestToken == current.token) {
      await signOut(SignOutReason.sessionExpired);
    }
  }

  /// Once the login screen has shown why the user was signed out.
  void clearSignOutReason() {
    if (state.status == SessionStatus.signedOut && state.signOutReason != null) {
      state = const SessionState.signedOut();
    }
  }
}
