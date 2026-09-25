import 'package:agrilink_mobile/core/storage/preferences.dart';
import 'package:agrilink_mobile/l10n/l10n.dart';
import 'package:agrilink_mobile/l10n/labels.dart';
import 'package:agrilink_mobile/l10n/locale_controller.dart';
import 'package:agrilink_mobile/shared/widgets/language_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('labels', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final si = lookupAppLocalizations(const Locale('si'));

    test('translate API status values and fall back to the raw value', () {
      expect(
        statusLabel(en, StatusKind.issue, 'AwaitingReview'),
        'Awaiting review',
      );
      expect(statusLabel(en, StatusKind.severity, 'High'), 'High');
      expect(statusLabel(en, StatusKind.order, 'Teleported'), 'Teleported');
      expect(
        statusLabel(si, StatusKind.issue, 'Pending'),
        si.commonStatusIssuePending,
      );
    });

    test('translate crop names with spaces, and roles', () {
      expect(cropLabel(en, 'Green Gram'), 'Green Gram');
      expect(cropLabel(si, 'Green Gram'), si.commonCropTypesGreenGram);
      expect(cropLabel(en, 'Dragon Fruit'), 'Dragon Fruit');
      expect(roleLabel(si, 'Farmer'), si.commonRolesFarmer);
    });
  });

  testWidgets('the language switcher changes and remembers the language', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            locale: ref.watch(languageProvider).locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    Text(context.l10n.authLoginSubmit),
                    const LanguageSwitcher(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Sign in'), findsOneWidget);

    await tester.tap(find.text('සිංහල'));
    await tester.pumpAndSettle();
    expect(find.text('පිවිසෙන්න'), findsOneWidget);
    expect(preferences.getString(PrefKeys.locale), 'si');

    await tester.tap(find.text('தமிழ்'));
    await tester.pumpAndSettle();
    expect(find.text('உள்நுழைக'), findsOneWidget);
  });
}
