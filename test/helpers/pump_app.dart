import 'package:agrilink_mobile/app/theme/app_theme.dart';
import 'package:agrilink_mobile/core/storage/preferences.dart';
import 'package:agrilink_mobile/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

extension PumpApp on WidgetTester {
  /// Pumps [child] inside the app's theme, translations and a [ProviderScope].
  Future<void> pumpApp(
    Widget child, {
    List<Override> overrides = const [],
    Locale locale = const Locale('en'),
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          ...overrides,
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: child),
        ),
      ),
    );
  }
}
