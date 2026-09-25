import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/session/session.dart';
import '../../../core/session/session_controller.dart';
import '../data/auth_api.dart';

/// Why a sign-in failed, so the login screen can say the right thing.
sealed class LoginFailure {
  const LoginFailure();

  /// Maps the API's answers (see AuthController.Login):
  /// 401 → wrong email or password (also a deactivated account),
  /// 403 with `reason` or "not approved" → rejected, other 403 → still pending.
  factory LoginFailure.from(Object error) {
    if (error is! ApiException) {
      return const LoginFailureOther(null);
    }
    if (error.isConnectivity) {
      return LoginFailureNetwork(timedOut: error.kind == ApiErrorKind.timeout);
    }
    switch (error.kind) {
      case ApiErrorKind.unauthorized:
      case ApiErrorKind.badRequest:
        return const LoginFailureInvalidCredentials();
      case ApiErrorKind.forbidden:
        final rejected =
            error.bodyField('reason') != null ||
            (error.serverMessage ?? '').toLowerCase().contains('not approved');
        return rejected
            ? LoginFailureRejected(error.bodyField('reason'))
            : const LoginFailurePending();
      case ApiErrorKind.network:
      case ApiErrorKind.timeout:
      case ApiErrorKind.cancelled:
      case ApiErrorKind.notFound:
      case ApiErrorKind.conflict:
      case ApiErrorKind.server:
      case ApiErrorKind.unknown:
        return LoginFailureOther(error.serverMessage);
    }
  }
}

class LoginFailureInvalidCredentials extends LoginFailure {
  const LoginFailureInvalidCredentials();
}

class LoginFailurePending extends LoginFailure {
  const LoginFailurePending();
}

class LoginFailureRejected extends LoginFailure {
  const LoginFailureRejected(this.reason);

  /// The officer's or admin's reason, if they gave one.
  final String? reason;
}

class LoginFailureNetwork extends LoginFailure {
  const LoginFailureNetwork({required this.timedOut});
  final bool timedOut;
}

class LoginFailureOther extends LoginFailure {
  const LoginFailureOther(this.serverMessage);
  final String? serverMessage;
}

/// Signing in and out. Screens call this; it updates the session, and the router moves the
/// user to the right place.
class AuthService {
  AuthService(this._ref);

  final Ref _ref;

  /// Throws [LoginFailure] when the sign-in is refused.
  Future<void> signIn({required String email, required String password}) async {
    try {
      final result = await _ref.read(authApiProvider).login(email: email, password: password);
      await _ref
          .read(sessionControllerProvider.notifier)
          .signIn(Session(token: result.token, role: result.role));
    } on Object catch (error) {
      throw LoginFailure.from(error);
    }
  }

  /// Clears the token. Every provider holding the user's data watches the session and is
  /// cleared with it (see `sessionTokenProvider`).
  Future<void> signOut() => _ref.read(sessionControllerProvider.notifier).signOut();
}

final authServiceProvider = Provider<AuthService>(AuthService.new);
