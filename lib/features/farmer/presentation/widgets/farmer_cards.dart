import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/format/formatters.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/labels.dart';
import '../../../../shared/widgets/crop_icon.dart';
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
  });

  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final List<Widget> lines;

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

/// One farm in the list.
class FarmCard extends StatelessWidget {
  const FarmCard({super.key, required this.farm, required this.onTap});

  final Farm farm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _ListCard(
      onTap: onTap,
      leading: Icon(Icons.agriculture_outlined, color: colors.forest),
      title: farm.name,
      lines: [
        Row(
          children: [
            Icon(Icons.location_on_outlined, size: 14, color: colors.textSecondary),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                farm.district,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.textSecondary),
              ),
            ),
          ],
        ),
        AcresText(farm.area),
      ],
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
      leading: CropIcon(crop.cropType, size: 26),
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
