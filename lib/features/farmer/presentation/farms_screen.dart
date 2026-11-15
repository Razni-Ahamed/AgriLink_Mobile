import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/api/api_error_parser.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/canopy/photo_banner.dart';
import '../../../shared/media/crop_photos.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/application/current_user.dart';
import '../application/farms.dart';
import '../data/crop.dart';
import '../farmer_paths.dart';
import 'widgets/farm_form.dart';
import 'widgets/farmer_cards.dart';
import 'widgets/today_widgets.dart';

/// The farmer's home, "Today": a greeting over a morning photo with the district's weather on
/// glass, then the growing crops (each its own photo, with the season growing along a vine), then
/// the farms. Pull to refresh reloads everything; the button adds a farm.
class FarmsScreen extends ConsumerWidget {
  const FarmsScreen({super.key});

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    try {
      ref.invalidate(myFarmsProvider);
      ref.invalidate(myCropsProvider);
      await ref.read(myFarmsProvider.future);
    } on Object catch (error) {
      if (context.mounted) {
        showToast(context, describeError(error, context.l10n), tone: ToastTone.error);
      }
    }
  }

  Future<void> _add(BuildContext context) async {
    final farm = await showFarmFormSheet(context);
    if (farm != null && context.mounted) {
      showToast(context, context.l10n.farmsListCreated, tone: ToastTone.success);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider).value;
    final crops = ref.watch(myCropsProvider).value ?? const <FarmerCrop>[];
    final growing = [
      for (final crop in crops)
        if (crop.status != CropStatus.harvested) crop,
    ];

    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.farmsListTitle),
      // With no farms the page already has its own "New Farm" button; two would be one too many.
      floatingActionButton: (ref.watch(myFarmsProvider).value?.isNotEmpty ?? false)
          ? FloatingActionButton.extended(
              key: const Key('new-farm'),
              onPressed: () => _add(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.farmsListNewFarm),
            )
          : null,
      body: AsyncValueView(
        value: ref.watch(myFarmsProvider),
        onRetry: () => ref.invalidate(myFarmsProvider),
        data: (farms) {
          if (farms.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => _refresh(context, ref),
              child: EmptyView(
                icon: Icons.agriculture_outlined,
                title: l10n.farmsListEmpty,
                action: FilledButton.icon(
                  onPressed: () => _add(context),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.farmsListNewFarm),
                ),
              ),
            );
          }
          // The farmer's own district, or their first farm's, for the weather.
          final district = (user?.district?.isNotEmpty ?? false)
              ? user!.district!
              : farms.first.district;
          final name = (user?.displayName?.trim().isNotEmpty ?? false)
              ? user!.displayName!.trim()
              : (user?.fullName ?? '').split(' ').first;
          final hour = DateTime.now().hour;
          final greeting = name.isEmpty
              ? l10n.farmsListTitle
              : hour < 12
              ? l10n.farmsTodayMorning(name)
              : hour < 17
              ? l10n.farmsTodayAfternoon(name)
              : l10n.farmsTodayEvening(name);

          return RefreshIndicator(
            onRefresh: () => _refresh(context, ref),
            child: ListView(
              key: const Key('farms-list'),
              // Room under the last card for the floating button.
              padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.sm, Gaps.md, 96),
              children: [
                PhotoBanner(
                  photo: Scenes.morning,
                  alignment: const Alignment(0, -0.3),
                  title: greeting,
                  subtitle: l10n.farmsTodaySubtitle,
                  child: WeatherCard(district: district),
                ),
                if (growing.isNotEmpty) ...[
                  const SizedBox(height: Gaps.lg),
                  Text(l10n.farmsTodayCrops, style: textTheme.titleLarge),
                  const SizedBox(height: Gaps.sm),
                  for (final crop in growing) ...[
                    CropSeasonCard(
                      key: Key('crop-season-${crop.id}'),
                      crop: crop,
                      onTap: () => context.go(FarmerPaths.crop(crop.farmId, crop.fieldId, crop.id)),
                    ),
                    const SizedBox(height: Gaps.sm),
                  ],
                ],
                const SizedBox(height: Gaps.lg),
                Text(l10n.farmsTodayFarms, style: textTheme.titleLarge),
                const SizedBox(height: Gaps.sm),
                for (final farm in farms) ...[
                  FarmCard(
                    key: Key('farm-${farm.id}'),
                    farm: farm,
                    onTap: () => context.go(FarmerPaths.farm(farm.id)),
                  ),
                  const SizedBox(height: Gaps.sm),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
