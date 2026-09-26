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
import '../../data/harvest_listing.dart';
import 'header_badge.dart';

/// One listing in a list, like the website's HarvestCard: the crop, where and when it was
/// harvested, the price and how much is left. [onTap] opens the listing.
class HarvestCard extends ConsumerWidget {
  const HarvestCard({super.key, required this.listing, required this.onTap, this.trailing});

  final HarvestListing listing;
  final VoidCallback onTap;

  /// Extra content under the details, e.g. the farmer's "3 of 5 available" on My Listings.
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = ref.watch(formattersProvider);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Card(
      key: Key('harvest-${listing.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gaps.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.tint(colors.forest),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: CropIcon(listing.cropType),
                    ),
                  ),
                  const SizedBox(width: Gaps.sm + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cropLabel(l10n, listing.cropType), style: text.titleLarge),
                        if (listing.variety.isNotEmpty)
                          Text(
                            listing.variety,
                            style: text.bodyMedium?.copyWith(color: colors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Gaps.sm),
                  HeaderBadge(
                    child: StatusBadge.status(StatusKind.harvest, listing.status.apiName),
                  ),
                ],
              ),
              const SizedBox(height: Gaps.sm + 4),
              _IconLine(icon: Icons.place_outlined, text: _place(listing)),
              const SizedBox(height: Gaps.xs),
              _IconLine(icon: Icons.event_outlined, text: format.date(listing.harvestDate)),
              const SizedBox(height: Gaps.sm + 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      l10n.commonUnitsRupeesPerUnit(format.number(listing.pricePerUnit)),
                      style: text.titleMedium!.mono.copyWith(color: colors.forest),
                    ),
                  ),
                  Text(
                    l10n.commonUnitsAvailableShort(
                      format.kilograms(l10n, listing.availableQuantity),
                    ),
                    style: text.bodyMedium!.mono.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }

  static String _place(HarvestListing listing) =>
      [listing.location, listing.district].where((part) => part.isNotEmpty).join(', ');
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.textSecondary;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: Gaps.xs + 2),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color)),
        ),
      ],
    );
  }
}
