import 'package:agrilink_mobile/app/theme/app_colors.dart';
import 'package:agrilink_mobile/app/theme/app_theme.dart';
import 'package:agrilink_mobile/app/theme/theme_mode_controller.dart';
import 'package:agrilink_mobile/core/storage/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppTheme', () {
    test('uses the website tokens for primary, secondary and backgrounds', () {
      final light = AppTheme.light;
      expect(light.colorScheme.primary, const Color(0xFF1F4D36));
      expect(light.colorScheme.secondary, const Color(0xFFD9A441));
      expect(light.scaffoldBackgroundColor, const Color(0xFFFAF7F0));
      expect(light.extension<AppColors>(), AppColors.light);

      final dark = AppTheme.dark;
      expect(dark.colorScheme.primary, const Color(0xFF7CBE8C));
      expect(dark.colorScheme.onSecondary, const Color(0xFF10170F));
      expect(dark.scaffoldBackgroundColor, const Color(0xFF0F1512));
      expect(dark.extension<AppColors>(), AppColors.dark);
    });

    test('falls back to the Noto fonts for Sinhala and Tamil', () {
      final style = AppTheme.light.textTheme.bodyMedium!;
      expect(style.fontFamily, 'PlusJakartaSans');
      expect(style.fontFamilyFallback, containsAll(['NotoSansSinhala', 'NotoSansTamil']));
      expect(AppTheme.light.textTheme.headlineSmall!.fontFamily, 'Fraunces');
    });
  });

  group('ThemeModeController', () {
    Future<ProviderContainer> containerWith(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('defaults to following the system', () async {
      final container = await containerWith({});
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('remembers the chosen mode', () async {
      final container = await containerWith({});
      await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);

      final preferences = container.read(sharedPreferencesProvider);
      expect(preferences.getString(PrefKeys.themeMode), 'dark');
    });

    test('restores a stored mode', () async {
      final container = await containerWith({PrefKeys.themeMode: 'light'});
      expect(container.read(themeModeProvider), ThemeMode.light);
    });
  });
}
