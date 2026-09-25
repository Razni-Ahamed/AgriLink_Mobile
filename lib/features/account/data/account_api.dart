import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../shared/media/photo_picker.dart';
import '../../auth/data/auth_models.dart';
import 'account_models.dart';

/// The result of asking to change a detail: an admin's change is applied straight away (an
/// email change also returns a new token), everyone else's waits for approval.
sealed class ChangeRequestResult {
  const ChangeRequestResult();
}

class ChangeApplied extends ChangeRequestResult {
  const ChangeApplied(this.profile);
  final UserProfile profile;
}

class ChangeAppliedWithNewToken extends ChangeRequestResult {
  const ChangeAppliedWithNewToken(this.auth);
  final AuthResult auth;
}

class ChangeRequested extends ChangeRequestResult {
  const ChangeRequested(this.request);
  final ChangeRequest request;
}

/// The signed-in user's own profile and security settings (`/api/users/me/...`).
class AccountApi {
  AccountApi(this._api);

  final ApiClient _api;

  UserProfile _profile(Object? data) => UserProfile.fromJson(asJson(data));

  Future<UserProfile> updateProfile(UpdateProfileRequest request) =>
      _api.put('/api/users/me/profile', body: request.toJson(), decode: _profile);

  /// Multipart, in a "photo" field. The server re-encodes it as a 512×512 JPEG.
  Future<UserProfile> uploadPhoto(PickedPhoto photo) => _api.post(
    '/api/users/me/photo',
    body: FormData.fromMap({
      'photo': MultipartFile.fromBytes(
        photo.bytes,
        filename: photo.fileName,
        contentType: DioMediaType.parse(PickedPhoto.contentType),
      ),
    }),
    decode: _profile,
  );

  Future<UserProfile> deletePhoto() => _api.delete('/api/users/me/photo', decode: _profile);

  /// Returns a new token: changing the password rotates the account's security stamp, and the
  /// old token (this one included) stops working.
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _api.post(
    '/api/users/me/password',
    body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    decode: (data) => AuthResult.fromJson(asJson(data)),
  );

  Future<SecuritySettings> security() =>
      _api.get('/api/users/me/security', decode: (data) => SecuritySettings.fromJson(asJson(data)));

  /// The "unlock" step of the security screen. A wrong password is a 400, not a 401, so it
  /// never signs the user out.
  Future<void> verifyPassword(String currentPassword) => _api.post(
    '/api/users/me/verify-password',
    body: {'currentPassword': currentPassword},
    decode: ApiClient.ignoreBody,
  );

  /// An empty [phoneNumber] clears it; only officers and admins may do that.
  Future<UserProfile> updatePhone({required String currentPassword, required String phoneNumber}) =>
      _api.put(
        '/api/users/me/phone',
        body: {'currentPassword': currentPassword, 'phoneNumber': phoneNumber},
        decode: _profile,
      );

  Future<ChangeRequestResult> requestChange({
    required String currentPassword,
    required ChangeRequestField field,
    required String newValue,
    required bool isAdmin,
  }) => _api.post(
    '/api/users/me/change-requests',
    body: {'currentPassword': currentPassword, 'field': field.apiName, 'newValue': newValue},
    decode: (data) {
      final json = asJson(data);
      if (!isAdmin) {
        return ChangeRequested(ChangeRequest.fromJson(json));
      }
      return field == ChangeRequestField.email
          ? ChangeAppliedWithNewToken(AuthResult.fromJson(json))
          : ChangeApplied(UserProfile.fromJson(json));
    },
  );

  Future<void> withdrawChangeRequest(int requestId) =>
      _api.delete('/api/users/me/change-requests/$requestId', decode: ApiClient.ignoreBody);
}

final accountApiProvider = Provider<AccountApi>((ref) => AccountApi(ref.watch(apiClientProvider)));
