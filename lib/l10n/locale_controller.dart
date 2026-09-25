import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/preferences.dart';

/// The app's three languages, with the same codes the website stores.
enum AppLanguage {
  en,
  si,
  ta;

  Locale get locale => Locale(name);

  /// The language's name in that language, so it is recognisable whatever language the app is
  /// in. Matches the website's `common.language.*` strings.
  String get nativeName => switch (this) {
    AppLanguage.en => 'English',
    AppLanguage.si => 'සිංහල',
    AppLanguage.ta => 'தமிழ்',
  };

  /// The Sri Lankan locale used for number, date and currency formatting, like the website's
  /// `en-LK` / `si-LK` / `ta-LK`.
  String get intlLocale => '${name}_LK';

  static AppLanguage fromCode(String? code) =>
      values.firstWhere((l) => l.name == code, orElse: () => AppLanguage.en);
}

/// The chosen language. English until the user picks another (like the website), then
/// remembered between launches.
final languageProvider = NotifierProvider<LanguageController, AppLanguage>(LanguageController.new);

class LanguageController extends Notifier<AppLanguage> {
  @override
  AppLanguage build() =>
      AppLanguage.fromCode(ref.watch(sharedPreferencesProvider).getString(PrefKeys.locale));

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    await ref.read(sharedPreferencesProvider).setString(PrefKeys.locale, language.name);
  }
}
