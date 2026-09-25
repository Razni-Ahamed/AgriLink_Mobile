import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';

/// The signed-in user's profile (`GET /api/users/me`), or null when signed out. Loaded after
/// sign-in and again when the session changes, and replaced by every profile update.
///
/// ```dart
/// final user = ref.watch(currentUserProvider).value;   // null while loading
/// Text(user?.shownName ?? '')
/// ```
final currentUserProvider = AsyncNotifierProvider<CurrentUserController, UserProfile?>(
  CurrentUserController.new,
);

class CurrentUserController extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final token = ref.watch(sessionTokenProvider);
    if (token == null) {
      return null;
    }
    return ref.read(authApiProvider).me();
  }

  /// Loads the profile again, keeping the old one on screen until the new one arrives.
  Future<void> refresh() async {
    if (ref.read(sessionTokenProvider) == null) {
      return;
    }
    state = await AsyncValue.guard(() => ref.read(authApiProvider).me());
  }

  /// Uses a profile an update endpoint just returned, instead of loading it again.
  void set(UserProfile profile) {
    if (ref.read(sessionTokenProvider) != null) {
      state = AsyncData(profile);
    }
  }
}
