import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/storage/preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  // Date names for en, si and ta, used by the formatters.
  await initializeDateFormatting();
  runApp(
    ProviderScope(
      // A failed request is shown with a "Try again" button instead of being retried
      // silently in the background, so turn off Riverpod's automatic retry.
      retry: (retryCount, error) => null,
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const AgriLinkApp(),
    ),
  );
}
