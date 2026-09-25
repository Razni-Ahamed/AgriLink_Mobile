// Copies the website's crop icons and default role avatars into the app as SVG assets.
//
//   dart run tool/import_web_icons.dart [--web <path to the website's frontend/src>]
//
// Reads (by default from ../AgriLink_SriLanka/frontend/src):
//   components/ui/icons/crops/*Icon.tsx            → assets/icons/crops/<name>.svg
//   components/ui/icons/custom/{TeaLeaf,RiceGrain,CropGeneric}Icon.tsx
//   components/ui/icons/avatars/<Role>Avatar.tsx   → assets/icons/avatars/<role>.svg
//   lib/cropCatalog.ts                              → lib/shared/widgets/crop_catalog.g.dart
//
// The icons draw in `currentColor`; the app recolours them with the theme (see CropIcon and
// UserAvatar). Re-run it if the website's icons or crop list change.

import 'dart:io';

const String defaultWebSource = '../AgriLink_SriLanka/frontend/src';
const String cropAssetDir = 'assets/icons/crops';
const String avatarAssetDir = 'assets/icons/avatars';
const String catalogFile = 'lib/shared/widgets/crop_catalog.g.dart';

/// The custom icons the crop catalogue uses, besides the ones in `icons/crops`.
const List<String> customCropIcons = [
  'TeaLeafIcon',
  'RiceGrainIcon',
  'CropGenericIcon',
];

const List<String> avatarRoles = ['Farmer', 'Buyer', 'Officer', 'Admin'];

/// JSX attribute names → SVG attribute names.
const Map<String, String> _attributeNames = {
  'strokeWidth': 'stroke-width',
  'strokeLinecap': 'stroke-linecap',
  'strokeLinejoin': 'stroke-linejoin',
  'strokeOpacity': 'stroke-opacity',
  'fillOpacity': 'fill-opacity',
  'fillRule': 'fill-rule',
  'clipRule': 'clip-rule',
};

/// Attributes that only make sense in React (sizing, styling, accessibility).
const Set<String> _droppedAttributes = {
  'width',
  'height',
  'className',
  'aria-hidden',
  'focusable',
  'key',
};

/// `TeaLeafIcon` → `tea_leaf`.
String assetNameFor(String componentName) {
  final base = componentName.replaceAll(RegExp(r'(Icon|Avatar)$'), '');
  return base
      .replaceAllMapped(RegExp('(?<=[a-z0-9])([A-Z])'), (m) => '_${m[1]}')
      .toLowerCase();
}

/// Turns JSX markup into SVG markup: attribute names, `{2}` values, dropped React-only props.
String jsxToSvg(String jsx) {
  return jsx
      .replaceAllMapped(RegExp(r'([A-Za-z-]+)=(\{([^}]*)\}|"([^"]*)")'), (m) {
        final name = m[1]!;
        if (_droppedAttributes.contains(name)) {
          return '';
        }
        final value = (m[3] ?? m[4]!).trim().replaceAll(
          RegExp(r'''^['"]|['"]$'''),
          '',
        );
        // Only literal numbers and strings can be converted, not real expressions.
        final literal = RegExp(r'''^([-\d.]+|".*"|'.*')$''');
        if (m[3] != null && !literal.hasMatch(m[3]!.trim())) {
          throw FormatException(
            'Cannot convert the JSX expression {${m[3]}} in $name',
          );
        }
        return '${_attributeNames[name] ?? name}="$value"';
      })
      .replaceAll(RegExp(r'[ \t]+(?=[ \t]*/?>)'), '')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ');
}

/// The `<svg>…</svg>` element of an icon component, as a standalone SVG file.
String iconSvg(String tsx, String file) {
  final match = RegExp(r'<svg[\s\S]*?</svg>').firstMatch(tsx);
  if (match == null) {
    throw FormatException('No <svg> element in $file');
  }
  final svg = jsxToSvg(match[0]!)
      .replaceFirst('<svg', '<svg xmlns="http://www.w3.org/2000/svg"');
  return '${_tidy(svg)}\n';
}

/// A default avatar: AvatarBadge's circle shell around the role's motif.
String avatarSvg(String tsx, String file) {
  final match = RegExp(r'<AvatarBadge[^>]*>([\s\S]*?)</AvatarBadge>')
      .firstMatch(tsx);
  if (match == null) {
    throw FormatException('No <AvatarBadge> in $file');
  }
  final motif = jsxToSvg(match[1]!).trim();
  return '${_tidy('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<circle cx="24" cy="24" r="24" fill="currentColor" fill-opacity="0.14"/>
<circle cx="24" cy="24" r="23" fill="none" stroke="currentColor" stroke-opacity="0.3" stroke-width="2"/>
<g fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
$motif
</g>
</svg>''')}\n';
}

String _tidy(String svg) => svg
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .join('\n');

class CatalogEntry {
  const CatalogEntry(this.value, this.group, this.component);
  final String value;
  final String group;
  final String component;
}

/// The `{ value, group, Icon }` rows of cropCatalog.ts, in order.
List<CatalogEntry> parseCatalog(String source) {
  final entries = [
    for (final m in RegExp(
      r"\{\s*value:\s*'([^']+)',\s*group:\s*'([a-z]+)',\s*Icon:\s*(\w+)\s*\}",
    ).allMatches(source))
      CatalogEntry(m[1]!, m[2]!, m[3]!),
  ];
  if (entries.isEmpty) {
    throw const FormatException('No catalogue entries found in cropCatalog.ts');
  }
  return entries;
}

String catalogSource(List<CatalogEntry> entries) {
  final buffer = StringBuffer()
    ..writeln(
      '// GENERATED by tool/import_web_icons.dart from the website\'s lib/cropCatalog.ts.',
    )
    ..writeln('// Do not edit by hand.')
    ..writeln()
    ..writeln("part of 'crop_icon.dart';")
    ..writeln()
    ..writeln('const List<CropCatalogEntry> cropCatalog = [');
  for (final entry in entries) {
    buffer.writeln(
      "  CropCatalogEntry('${entry.value}', CropGroup.${entry.group}, "
      "'${assetNameFor(entry.component)}'),",
    );
  }
  buffer.writeln('];');
  return buffer.toString();
}

void main(List<String> args) {
  var web = defaultWebSource;
  final index = args.indexOf('--web');
  if (index != -1 && index + 1 < args.length) {
    web = args[index + 1];
  }
  final icons = Directory('$web/components/ui/icons');
  if (!icons.existsSync()) {
    stderr.writeln(
      "Can't find the website's icons at ${icons.path}.\n"
      'Clone https://github.com/Razni-Ahamed/AgriLink_SriLanka next to this repository, '
      'or pass --web <path to frontend/src>.',
    );
    exit(2);
  }

  Directory(cropAssetDir).createSync(recursive: true);
  Directory(avatarAssetDir).createSync(recursive: true);

  final cropFiles = [
    ...Directory('${icons.path}/crops')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('Icon.tsx')),
    for (final name in customCropIcons) File('${icons.path}/custom/$name.tsx'),
  ];
  for (final file in cropFiles) {
    final component = file.uri.pathSegments.last.replaceAll('.tsx', '');
    File('$cropAssetDir/${assetNameFor(component)}.svg')
        .writeAsStringSync(iconSvg(file.readAsStringSync(), file.path));
  }

  for (final role in avatarRoles) {
    final file = File('${icons.path}/avatars/${role}Avatar.tsx');
    File('$avatarAssetDir/${role.toLowerCase()}.svg')
        .writeAsStringSync(avatarSvg(file.readAsStringSync(), file.path));
  }

  final catalog = parseCatalog(
    File('$web/lib/cropCatalog.ts').readAsStringSync(),
  );
  for (final entry in catalog) {
    final asset = File('$cropAssetDir/${assetNameFor(entry.component)}.svg');
    if (!asset.existsSync()) {
      stderr.writeln(
        'error: ${entry.value} uses ${entry.component}, which was not converted',
      );
      exit(1);
    }
  }
  File(catalogFile).writeAsStringSync(catalogSource(catalog));

  stdout.writeln(
    'Wrote ${cropFiles.length} crop icons, ${avatarRoles.length} avatars and '
    '${catalog.length} catalogue entries.',
  );
}
