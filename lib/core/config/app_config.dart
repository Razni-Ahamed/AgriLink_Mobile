/// Build-time settings. Change the API with
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5266` (a backend on your own PC,
/// seen from the Android emulator; `localhost` would be the emulator itself).
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://agrilink-api-sl.azurewebsites.net',
  );

  /// The API's free hosting tier sleeps when idle, and the first request after that can take
  /// 10–30 seconds, so connecting gets a generous timeout.
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 45);

  /// Photo uploads on a slow mobile connection.
  static const Duration sendTimeout = Duration(seconds: 60);

  /// How often the unread notification count is refreshed while the app is open.
  static const Duration unreadCountPollInterval = Duration(seconds: 60);

  /// The page size list screens ask for.
  static const int defaultPageSize = 20;
}
