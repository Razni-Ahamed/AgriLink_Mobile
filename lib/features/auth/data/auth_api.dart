import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import 'auth_models.dart';

/// Sign-in, registration and the signed-in user's profile.
class AuthApi {
  AuthApi(this._api);

  final ApiClient _api;

  /// One sign-in for every role. `/api/auth/admin/login` exists for the website's separate
  /// admin console only; this endpoint returns the Admin role too.
  Future<AuthResult> login({required String email, required String password}) => _api.post(
    '/api/auth/login',
    body: {'email': email.trim(), 'password': password},
    decode: (data) => AuthResult.fromJson(asJson(data)),
  );

  /// Creates a pending account. The user can't sign in until it is approved.
  Future<void> register(RegisterRequest request) =>
      _api.post('/api/auth/register', body: request.toJson(), decode: ApiClient.ignoreBody);

  /// Anonymous. While signed in, the caller's own username counts as available.
  Future<UsernameAvailability> checkUsername(String username, {CancelToken? cancelToken}) =>
      _api.get(
        '/api/users/username-available',
        query: {'username': username},
        decode: (data) => UsernameAvailability.fromJson(asJson(data)),
        cancelToken: cancelToken,
      );

  Future<UserProfile> me() =>
      _api.get('/api/users/me', decode: (data) => UserProfile.fromJson(asJson(data)));
}

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(apiClientProvider)));
