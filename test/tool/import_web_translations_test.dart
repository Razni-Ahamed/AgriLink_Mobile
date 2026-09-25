import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/import_web_translations.dart';

void main() {
  group('arbKeyFor', () {
    test('joins the namespace and path in camelCase', () {
      expect(arbKeyFor('auth.login.submit'), 'authLoginSubmit');
      expect(arbKeyFor('common.passwordChecklist.length'), 'commonPasswordChecklistLength');
      expect(arbKeyFor('common.status.issue.AwaitingReview'), 'commonStatusIssueAwaitingReview');
    });

    test('splits words on characters a Dart name cannot have', () {
      expect(arbKeyFor('common.cropTypes.Green Gram'), 'commonCropTypesGreenGram');
      expect(arbKeyFor('common.cropTypes.Passion Fruit'), 'commonCropTypesPassionFruit');
    });
  });

  group('convertValue', () {
    test('turns i18next placeholders into ARB placeholders', () {
      expect(convertValue('Page {{page}} of {{ totalPages }}', 'k'), 'Page {page} of {totalPages}');
      expect(convertValue('No placeholders', 'k'), 'No placeholders');
    });

    test('rejects a stray brace and nested references', () {
      expect(() => convertValue('Use { carefully', 'k'), throwsA(isA<TranslationException>()));
      expect(() => convertValue(r'See $t(other)', 'k'), throwsA(isA<TranslationException>()));
    });
  });

  test('flatten keeps nesting as dotted keys', () {
    final flat = flatten({
      'login': {
        'submit': 'Sign in',
        'nested': {'deep': 'x'},
      },
    }, 'auth');
    expect(flat, {'auth.login.submit': 'Sign in', 'auth.login.nested.deep': 'x'});
  });

  group('buildArbs', () {
    Map<String, Map<String, String>> web() => {
      'en': {'auth.login.submit': 'Sign in', 'common.pageOf': 'Page {{page}} of {{total}}'},
      'si': {'auth.login.submit': 'පිවිසෙන්න', 'common.pageOf': '{{total}} න් {{page}} පිටුව'},
      'ta': {'auth.login.submit': 'உள்நுழைக'},
    };
    Map<String, Map<String, String>> mobile() => {
      'en': {'common.actions.retry': 'Try again'},
      'si': {'common.actions.retry': 'නැවත උත්සාහ කරන්න'},
      'ta': {'common.actions.retry': 'மீண்டும் முயற்சிக்கவும்'},
    };

    test('writes values, placeholder metadata and the mobile section', () {
      final warnings = <String>[];
      final arbs = buildArbs(web: web(), mobile: mobile(), warnings: warnings);
      final en = arbs['en']!;

      expect(en['@@locale'], 'en');
      expect(en['authLoginSubmit'], 'Sign in');
      expect(en['commonPageOf'], 'Page {page} of {total}');
      expect(en['@commonPageOf'], {
        'description': 'Website key: common.pageOf',
        'placeholders': {
          'page': {'type': 'Object'},
          'total': {'type': 'Object'},
        },
      });
      expect(en['commonActionsRetry'], 'Try again');
      expect(en['@commonActionsRetry'], {'description': 'Mobile-only key: common.actions.retry'});
      final keys = en.keys.toList();
      expect(keys.indexOf('@@x-mobile-only'), lessThan(keys.indexOf('commonActionsRetry')));

      // Word order differs in Sinhala; the placeholders still match.
      expect(arbs['si']!['commonPageOf'], '{total} න් {page} පිටුව');
      // Metadata lives in the English template only.
      expect(arbs['si']!.containsKey('@authLoginSubmit'), isFalse);

      expect(arbs['ta']!.containsKey('commonPageOf'), isFalse);
      expect(warnings, contains('ta is missing "common.pageOf"; English will be shown.'));
    });

    test('rejects a translation whose placeholders differ from English', () {
      final broken = web()..['si'] = {'common.pageOf': 'පිටුව {{page}}'};
      expect(
        () => buildArbs(web: broken, mobile: mobile()),
        throwsA(
          isA<TranslationException>().having((e) => e.message, 'message', contains('placeholders')),
        ),
      );
    });

    test('rejects a mobile key that repeats a website key', () {
      final clash = mobile()..['en'] = {'auth.login.submit': 'Log in'};
      expect(() => buildArbs(web: web(), mobile: clash), throwsA(isA<TranslationException>()));
    });

    test('rejects two keys that flatten to the same name', () {
      final clash = web()..['en'] = {'a.bC': 'one', 'aB.c': 'two'};
      expect(() => buildArbs(web: clash, mobile: {}), throwsA(isA<TranslationException>()));
    });
  });

  test('buildLookupSource maps placeholder-free keys to getters', () {
    final arbs = buildArbs(
      web: {
        'en': {'auth.login.submit': 'Sign in', 'common.pageOf': 'Page {{page}}'},
        'si': {},
        'ta': {},
      },
      mobile: {},
    );
    final source = buildLookupSource(arbs['en']!);
    expect(source, contains("'auth.login.submit' => l10n.authLoginSubmit,"));
    expect(source, isNot(contains('commonPageOf')));
  });

  group('the committed ARB files', () {
    Map<String, dynamic> read(String language) =>
        jsonDecode(File('lib/l10n/arb/app_$language.arb').readAsStringSync())
            as Map<String, dynamic>;
    Iterable<String> messageKeys(Map<String, dynamic> arb) =>
        arb.keys.where((k) => !k.startsWith('@'));

    test('cover every website namespace in all three languages', () {
      final en = read('en');
      expect(messageKeys(en).length, greaterThanOrEqualTo(734));
      for (final namespace in webNamespaces) {
        expect(messageKeys(en).any((k) => k.startsWith(namespace)), isTrue, reason: namespace);
      }
      for (final language in ['si', 'ta']) {
        expect(messageKeys(read(language)).toSet(), messageKeys(en).toSet(), reason: language);
      }
    });

    test('use the same placeholders in every language', () {
      final en = read('en');
      for (final language in ['si', 'ta']) {
        final other = read(language);
        for (final key in messageKeys(en)) {
          final expected = placeholdersIn(en[key] as String)..sort();
          final actual = placeholdersIn(other[key] as String)..sort();
          expect(actual, expected, reason: '$language $key');
        }
      }
    });
  });
}
