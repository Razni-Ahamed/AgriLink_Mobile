import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/l10n.dart';

part 'crop_catalog.g.dart';

/// The crop groups pickers are sorted into, as on the website.
enum CropGroup { plantation, cereals, roots, vegetables, fruit, other }

/// How a crop is drawn and grouped. The backend's crop list (`GET /api/crop-types`) decides
/// which crops are valid; this only says how to show them. The list itself, [cropCatalog], is
/// generated from the website's `cropCatalog.ts` by `tool/import_web_icons.dart`.
class CropCatalogEntry {
  const CropCatalogEntry(this.value, this.group, this.iconName);

  /// The crop name exactly as the API uses it ("Green Gram").
  final String value;
  final CropGroup group;

  /// The SVG in `assets/icons/crops/`.
  final String iconName;

  String get assetPath => 'assets/icons/crops/$iconName.svg';
}

/// The catalogue entry for a crop name. A crop the list doesn't know (older data, or one the
/// server added first) gets the generic icon in the "other" group, so it still shows.
CropCatalogEntry cropCatalogEntry(String cropType) {
  final key = cropType.trim().toLowerCase();
  for (final entry in cropCatalog) {
    if (entry.value.toLowerCase() == key) {
      return entry;
    }
  }
  return CropCatalogEntry(cropType, CropGroup.other, 'crop_generic');
}

/// Sort position for a crop name, so pickers show crops in catalogue order.
int cropCatalogOrder(String cropType) {
  final key = cropType.trim().toLowerCase();
  final index = cropCatalog.indexWhere((e) => e.value.toLowerCase() == key);
  return index == -1 ? cropCatalog.length : index;
}

String cropGroupLabel(AppLocalizations l10n, CropGroup group) => switch (group) {
  CropGroup.plantation => l10n.commonCropGroupsPlantation,
  CropGroup.cereals => l10n.commonCropGroupsCereals,
  CropGroup.roots => l10n.commonCropGroupsRoots,
  CropGroup.vegetables => l10n.commonCropGroupsVegetables,
  CropGroup.fruit => l10n.commonCropGroupsFruit,
  CropGroup.other => l10n.commonCropGroupsOther,
};

/// The website's icon for a crop, drawn in [color] (the forest green by default).
///
/// ```dart
/// CropIcon('Paddy', size: 28)
/// ```
class CropIcon extends StatelessWidget {
  const CropIcon(this.cropType, {super.key, this.size = 24, this.color});

  final String cropType;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      cropCatalogEntry(cropType).assetPath,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        color ?? Theme.of(context).colorScheme.primary,
        BlendMode.srcIn,
      ),
      excludeFromSemantics: true,
    );
  }
}
