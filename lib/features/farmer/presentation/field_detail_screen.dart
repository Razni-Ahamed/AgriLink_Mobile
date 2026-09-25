import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/api/api_error_parser.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/farms.dart';
import '../farmer_paths.dart';
import 'widgets/crop_form.dart';
import 'widgets/farmer_cards.dart';
import 'widgets/inline_states.dart';

/// One field: its details and the crops planted in it, with a button to plant another.
class FieldDetailScreen extends ConsumerWidget {
  const FieldDetailScreen({super.key, required this.farmId, required this.fieldId});

  final int farmId;
  final int fieldId;

  FieldKey get _key => (farmId: farmId, fieldId: fieldId);

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    ref.invalidate(fieldCropsProvider(fieldId));
    try {
      ref.invalidate(farmFieldsProvider(farmId));
      await ref.read(fieldProvider(_key).future);
    } on Object catch (error) {
      if (context.mounted) {
        showToast(context, describeError(error, context.l10n), tone: ToastTone.error);
      }
    }
  }

  Future<void> _plant(BuildContext context) async {
    final crop = await showCropFormSheet(context, fieldId: fieldId);
    if (crop != null && context.mounted) {
      showToast(context, context.l10n.farmsFieldCropPlanted, tone: ToastTone.success);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fieldAsync = ref.watch(fieldProvider(_key));
    return Scaffold(
      appBar: AgriLinkAppBar(title: fieldAsync.value?.name ?? l10n.farmsFieldCrops),
      floatingActionButton: fieldAsync.value == null
          ? null
          : FloatingActionButton.extended(
              key: const Key('plant-crop'),
              onPressed: () => _plant(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.farmsFieldPlantCrop),
            ),
      body: AsyncValueView(
        value: fieldAsync,
        onRetry: () => ref.invalidate(farmFieldsProvider(farmId)),
        data: (field) => field == null
            ? EmptyView(icon: Icons.search_off_outlined, title: l10n.farmsFieldNotFound)
            : RefreshIndicator(
                onRefresh: () => _refresh(context, ref),
                child: _content(context, ref, field.name, field.area),
              ),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, String name, double area) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final crops = ref.watch(fieldCropsProvider(fieldId));
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.md, Gaps.md, 96),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gaps.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: textTheme.headlineSmall),
                const SizedBox(height: Gaps.xs),
                AcresText(area, style: textTheme.titleMedium),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gaps.lg),
        Semantics(header: true, child: Text(l10n.farmsFieldCrops, style: textTheme.titleLarge)),
        const SizedBox(height: Gaps.sm),
        InlineAsyncView(
          value: crops,
          onRetry: () => ref.invalidate(fieldCropsProvider(fieldId)),
          data: (list) => list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gaps.sm),
                  child: Text(
                    l10n.farmsFieldNoCropsYet,
                    style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                  ),
                )
              : Column(
                  children: [
                    for (final crop in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gaps.sm),
                        child: CropCard(
                          key: Key('crop-${crop.id}'),
                          crop: crop,
                          onTap: () => context.go(FarmerPaths.crop(farmId, fieldId, crop.id)),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
