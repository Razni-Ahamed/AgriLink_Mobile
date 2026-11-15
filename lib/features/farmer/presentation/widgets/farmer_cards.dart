import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/format/formatters.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/labels.dart';
import '../../../../shared/media/crop_photos.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/crop.dart';
import '../../data/farm.dart';

/// The frame all three cards share: an icon, a title and a few lines of detail.
class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.onTap,
    required this.leading,
    required this.title,
    required this.lines,
    this.photoLeading = false,
  });

  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final List<Widget> lines;

  /// [leading] is a photo: shown as a rounded square, without the tinted circle behind icons.
  final bool photoLeading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gaps.md),
          child: Row(
            children: [
              if (photoLeading)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox.square(dimension: 52, child: leading),
                )
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.tint(colors.forest),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(dimension: 44, child: Center(child: leading)),
                ),
              const SizedBox(width: Gaps.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    for (final line in lines) ...[const SizedBox(height: 2), line],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// The area in acres, in the number font, in the app's green.
class AcresText extends ConsumerWidget {
  const AcresText(this.area, {super.key, this.style});

  final double area;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = ref.watch(formattersProvider);
    final base = style ?? Theme.of(context).textTheme.bodyMedium!;
    return Text(
      context.l10n.commonUnitsAcres(format.number(area)),
      style: base.mono.copyWith(color: context.colors.forest),
    );
  }
}

/// One farm in the list: a field photo on top (the same one the website shows for this farm),
/// then the name, district and area. Lifts slightly while pressed.
class FarmCard extends StatelessWidget {
  const FarmCard({super.key, required this.farm, required this.onTap});

  final Farm farm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 120,
                  child: Image.asset(Scenes.forFarm(farm.id), fit: BoxFit.cover),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(farm.name, style: textTheme.titleLarge),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: colors.textSecondary,
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  districtLabel(context.l10n, farm.district),
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.tint(colors.forest),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        child: AcresText(farm.area),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One field on a farm.
class FieldCard extends StatelessWidget {
  const FieldCard({super.key, required this.field, required this.onTap});

  final FarmField field;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ListCard(
      onTap: onTap,
      leading: Icon(Icons.grid_view_outlined, color: context.colors.harvest),
      title: field.name,
      lines: [AcresText(field.area)],
    );
  }
}

/// One crop in a field, with its status.
class CropCard extends StatelessWidget {
  const CropCard({super.key, required this.crop, required this.onTap});

  final Crop crop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return _ListCard(
      onTap: onTap,
      photoLeading: true,
      leading: Image.asset(cropPhotoAsset(crop.cropType), fit: BoxFit.cover),
      title: cropLabel(l10n, crop.cropType),
      lines: [
        Text(
          crop.variety.isEmpty ? l10n.farmsCropNoVariety : crop.variety,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusBadge.status(StatusKind.crop, crop.status.apiName),
          ),
        ),
      ],
    );
  }
}
