import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret settings that survive a restart: the language and the theme mode.
///
/// Loaded once in `main()` and injected with `overrideWithValue`, so every reader gets it
/// synchronously. Tests use `SharedPreferences.setMockInitialValues` and override it the same way.
/// The session token is not stored here: it lives in secure storage (see `session_storage.dart`).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  ),
);

/// Keys for [sharedPreferencesProvider]. Keep every key here so none collide.
abstract final class PrefKeys {
  static const String themeMode = 'agrilink.themeMode';
  static const String locale = 'agrilink.locale';
  static const String notificationPermissionAsked =
      'agrilink.notificationPermissionAsked';
}
