// Imports the website's translations into the app's ARB files.
//
//   dart run tool/import_web_translations.dart [--web <path to the website's locales folder>]
//
// Reads `frontend/src/i18n/locales/{en,si,ta}/*.json` from the website repository (by default
// `../AgriLink_SriLanka`, cloned next to this one) plus the app's own `lib/l10n/mobile/*.json`,
// and writes:
//
//   lib/l10n/arb/app_{en,si,ta}.arb   the input for `flutter gen-l10n`
//   lib/l10n/web_keys.g.dart          translateWebKey(): look a string up by its website key
//
// Key naming: `<namespace>.<path>` becomes camelCase, so `auth.json` → `login.submit` is
// `authLoginSubmit`, and `common.json` → `cropTypes.Green Gram` is `commonCropTypesGreenGram`.
// i18next's `{{name}}` placeholders become ARB `{name}`.
//
// Re-run it whenever the website's translations change, then run `flutter pub get` (or
// `flutter gen-l10n`) to regenerate AppLocalizations. See docs/ARCHITECTURE.md.

import 'dart:convert';
import 'dart:io';

const List<String> languages = ['en', 'si', 'ta'];
const String templateLanguage = 'en';

/// The website's namespaces, in the order they appear in the ARB files.
const List<String> webNamespaces = [
  'common',
  'auth',
  'farms',
  'home',
  'issues',
  'marketplace',
  'officer',
  'orders',
  'registrations',
];

const String defaultWebLocales =
    '../AgriLink_SriLanka/frontend/src/i18n/locales';
const String mobileDir = 'lib/l10n/mobile';
const String arbDir = 'lib/l10n/arb';
const String lookupFile = 'lib/l10n/web_keys.g.dart';

class TranslationException implements Exception {
  TranslationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One translatable string, keyed by its dotted website key (`auth.login.submit`).
class Entry {
  Entry(this.webKey, this.value, {required this.mobileOnly});
  final String webKey;
  final String value;
  final bool mobileOnly;
}

final RegExp _i18nextPlaceholder = RegExp(
  r'\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}',
);
final RegExp _arbPlaceholder = RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)\}');

/// `auth.login.submit` → `authLoginSubmit`. Any character that can't be in a Dart identifier
/// (a space, a dash) splits a word: `common.cropTypes.Green Gram` → `commonCropTypesGreenGram`.
String arbKeyFor(String webKey) {
  final words = webKey
      .split(RegExp('[^A-Za-z0-9]+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) {
    throw TranslationException('Cannot build a key from "$webKey"');
  }
  final buffer = StringBuffer(
    words.first[0].toLowerCase() + words.first.substring(1),
  );
  for (final word in words.skip(1)) {
    buffer.write(word[0].toUpperCase() + word.substring(1));
  }
  final key = buffer.toString();
  if (!RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(key)) {
    throw TranslationException(
      '"$webKey" gives "$key", which is not a valid Dart identifier',
    );
  }
  return key;
}

/// `Hello {{name}}` → `Hello {name}`. Throws on a brace that isn't part of a placeholder,
/// because ARB would read it as ICU syntax.
String convertValue(String value, String webKey) {
  final converted = value.replaceAllMapped(
    _i18nextPlaceholder,
    (m) => '{${m[1]}}',
  );
  final leftover = converted.replaceAll(_arbPlaceholder, '');
  if (leftover.contains('{') || leftover.contains('}')) {
    throw TranslationException(
      '"$webKey" has a brace that is not a {{placeholder}}: $value',
    );
  }
  if (value.contains(r'$t(')) {
    throw TranslationException(
      '"$webKey" uses a nested \$t() reference, which ARB cannot express',
    );
  }
  return converted;
}

/// Placeholder names in an already-converted ARB value, in order of first use.
List<String> placeholdersIn(String arbValue) {
  final names = <String>[];
  for (final match in _arbPlaceholder.allMatches(arbValue)) {
    if (!names.contains(match[1])) {
      names.add(match[1]!);
    }
  }
  return names;
}

/// Flattens nested i18next JSON into dotted keys, keeping the file's order.
Map<String, String> flatten(Object? json, String prefix) {
  final result = <String, String>{};
  void walk(Object? node, String path) {
    if (node is Map) {
      for (final entry in node.entries) {
        walk(entry.value, path.isEmpty ? '${entry.key}' : '$path.${entry.key}');
      }
    } else if (node is String) {
      result[path] = node;
    } else {
      throw TranslationException('"$path" is not a string or an object: $node');
    }
  }

  walk(json, prefix);
  return result;
}

/// Builds the ARB maps for every language from already-flattened entries.
///
/// [web] and [mobile] map language → (dotted key → i18next value). Mobile keys must not repeat a
/// website key. Every language's placeholders must match English, or the generated method
/// signatures would not fit the translation.
Map<String, Map<String, Object>> buildArbs({
  required Map<String, Map<String, String>> web,
  required Map<String, Map<String, String>> mobile,
  List<String>? warnings,
}) {
  warnings ??= [];
  final template = <Entry>[
    for (final e in web[templateLanguage]!.entries)
      Entry(e.key, e.value, mobileOnly: false),
    for (final e in (mobile[templateLanguage] ?? {}).entries)
      Entry(e.key, e.value, mobileOnly: true),
  ];

  final arbKeys = <String, String>{};
  final seenWebKeys = <String>{};
  for (final entry in template) {
    if (!seenWebKeys.add(entry.webKey)) {
      throw TranslationException(
        'The mobile-only key "${entry.webKey}" already exists on the website. '
        'Remove it from $mobileDir or use the website string.',
      );
    }
    final arbKey = arbKeyFor(entry.webKey);
    final clash = arbKeys[arbKey];
    if (clash != null) {
      throw TranslationException(
        '"$clash" and "${entry.webKey}" both become "$arbKey"',
      );
    }
    arbKeys[arbKey] = entry.webKey;
  }

  final arbs = <String, Map<String, Object>>{};
  for (final language in languages) {
    final arb = <String, Object>{
      '@@locale': language,
      '@@x-source':
          'Generated by tool/import_web_translations.dart. Do not edit by hand: change the '
          "website's frontend/src/i18n/locales or lib/l10n/mobile, then re-run the script.",
    };
    var mobileSectionStarted = false;
    for (final entry in template) {
      final source = entry.mobileOnly ? mobile[language] : web[language];
      final raw = source?[entry.webKey];
      if (entry.mobileOnly && !mobileSectionStarted) {
        mobileSectionStarted = true;
        arb['@@x-mobile-only'] =
            'The keys below are mobile-only strings from lib/l10n/mobile/$language.json.';
      }
      if (raw == null) {
        if (language != templateLanguage) {
          warnings.add(
            '$language is missing "${entry.webKey}"; English will be shown.',
          );
        }
        continue;
      }
      final arbKey = arbKeyFor(entry.webKey);
      final value = convertValue(raw, entry.webKey);
      final templateValue = convertValue(entry.value, entry.webKey);
      final expected = placeholdersIn(templateValue)..sort();
      final actual = placeholdersIn(value)..sort();
      if (expected.join(',') != actual.join(',')) {
        throw TranslationException(
          '$language "${entry.webKey}" has placeholders $actual but English has $expected',
        );
      }
      arb[arbKey] = value;
      if (language == templateLanguage) {
        arb['@$arbKey'] = {
          'description':
              '${entry.mobileOnly ? 'Mobile-only' : 'Website'} key: ${entry.webKey}',
          if (expected.isNotEmpty)
            'placeholders': {
              for (final name in placeholdersIn(templateValue))
                name: {'type': 'Object'},
            },
        };
      }
    }
    for (final extra in (web[language] ?? {}).keys) {
      if (!web[templateLanguage]!.containsKey(extra)) {
        warnings.add(
          '$language has "$extra", which English does not; it was skipped.',
        );
      }
    }
    arbs[language] = arb;
  }
  return arbs;
}

/// Dart source for `translateWebKey()`: a switch from every placeholder-free dotted key to its
/// AppLocalizations getter, for strings chosen at runtime (status values, crop names).
String buildLookupSource(Map<String, Object> templateArb) {
  final buffer = StringBuffer()
    ..writeln(
      '// GENERATED by tool/import_web_translations.dart. Do not edit by hand.',
    )
    ..writeln()
    ..writeln("import 'generated/app_localizations.dart';")
    ..writeln()
    ..writeln(
      '/// The translation of a website key such as `common.status.issue.Pending`, or null',
    )
    ..writeln(
      '/// when there is no such key. Only strings without placeholders are included.',
    )
    ..writeln('///')
    ..writeln(
      '/// Use it for text picked by a value from the API. For fixed text, call the getter',
    )
    ..writeln(
      '/// directly (`context.l10n.commonStatusIssuePending`) so a typo fails to compile.',
    )
    ..writeln('String? translateWebKey(AppLocalizations l10n, String key) {')
    ..writeln('  return switch (key) {');
  for (final entry in templateArb.entries) {
    if (entry.key.startsWith('@')) {
      continue;
    }
    final meta = templateArb['@${entry.key}']! as Map<String, Object>;
    if (meta.containsKey('placeholders')) {
      continue;
    }
    final webKey = (meta['description']! as String).split('key: ').last;
    buffer.writeln(
      "    '${webKey.replaceAll("'", r"\'")}' => l10n.${entry.key},",
    );
  }
  buffer
    ..writeln('    _ => null,')
    ..writeln('  };')
    ..writeln('}');
  return buffer.toString();
}

Map<String, String> readNamespaceFiles(String localesDir, String language) {
  final result = <String, String>{};
  for (final namespace in webNamespaces) {
    final file = File('$localesDir/$language/$namespace.json');
    if (!file.existsSync()) {
      throw TranslationException('Missing ${file.path}');
    }
    result.addAll(flatten(jsonDecode(file.readAsStringSync()), namespace));
  }
  return result;
}

Map<String, String> readMobileFile(String language) {
  final file = File('$mobileDir/$language.json');
  if (!file.existsSync()) {
    return {};
  }
  final json = jsonDecode(file.readAsStringSync());
  if (json is! Map) {
    throw TranslationException('${file.path} must be an object of namespaces');
  }
  return flatten(json, '');
}

void main(List<String> args) {
  var localesDir = defaultWebLocales;
  final webIndex = args.indexOf('--web');
  if (webIndex != -1 && webIndex + 1 < args.length) {
    localesDir = args[webIndex + 1];
  }
  if (!Directory(localesDir).existsSync()) {
    stderr.writeln(
      "Can't find the website's locales at $localesDir.\n"
      'Clone https://github.com/Razni-Ahamed/AgriLink_SriLanka next to this repository, '
      'or pass --web <path to frontend/src/i18n/locales>.',
    );
    exit(2);
  }

  try {
    final warnings = <String>[];
    final arbs = buildArbs(
      web: {for (final l in languages) l: readNamespaceFiles(localesDir, l)},
      mobile: {for (final l in languages) l: readMobileFile(l)},
      warnings: warnings,
    );
    Directory(arbDir).createSync(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    for (final language in languages) {
      File('$arbDir/app_$language.arb')
          .writeAsStringSync('${encoder.convert(arbs[language])}\n');
    }
    File(lookupFile)
        .writeAsStringSync(buildLookupSource(arbs[templateLanguage]!));

    final count = arbs[templateLanguage]!.keys
        .where((k) => !k.startsWith('@'))
        .length;
    stdout.writeln(
      'Wrote $count strings to $arbDir/app_{${languages.join(',')}}.arb and $lookupFile',
    );
    for (final warning in warnings) {
      stdout.writeln('warning: $warning');
    }
    stdout.writeln(
      'Now run `flutter pub get` (or `flutter gen-l10n`) to regenerate AppLocalizations.',
    );
  } on TranslationException catch (e) {
    stderr.writeln('error: $e');
    exit(1);
  }
}
