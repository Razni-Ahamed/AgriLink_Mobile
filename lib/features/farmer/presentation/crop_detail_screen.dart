import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/api/api_error_parser.dart';
import '../../../core/format/formatters.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/labels.dart';
import '../../../shared/widgets/crop_icon.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/farms.dart';
import '../data/crop.dart';
import '../data/crops_api.dart';

/// One crop: its details, and its status, which is the only thing that can change once a crop
/// is planted. Changing it asks first, since the API can't remove or edit a crop.
class CropDetailScreen extends ConsumerStatefulWidget {
  const CropDetailScreen({super.key, required this.fieldId, required this.cropId});

  final int fieldId;
  final int cropId;

  @override
  ConsumerState<CropDetailScreen> createState() => _CropDetailScreenState();
}

class _CropDetailScreenState extends ConsumerState<CropDetailScreen> {
  bool _updating = false;

  Future<void> _refresh() async {
    try {
      ref.invalidate(cropProvider(widget.cropId));
      await ref.read(cropProvider(widget.cropId).future);
    } on Object catch (error) {
      if (mounted) {
        showToast(context, describeError(error, context.l10n), tone: ToastTone.error);
      }
    }
  }

  Future<void> _changeStatus(Crop crop, CropStatus status) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.farmsCropChangeStatusTitle,
      message: l10n.farmsCropChangeStatusMessage(
        statusLabel(l10n, StatusKind.crop, crop.status.apiName),
        statusLabel(l10n, StatusKind.crop, status.apiName),
      ),
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _updating = true);
    try {
      await ref.read(cropsApiProvider).updateStatus(crop.id, status);
      if (!mounted) {
        return;
      }
      ref
        ..invalidate(cropProvider(crop.id))
        ..invalidate(fieldCropsProvider(crop.fieldId))
        ..invalidate(myCropsProvider);
      showToast(context, l10n.farmsCropStatusUpdated, tone: ToastTone.success);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final parsed = parseApiError(error, l10n, generic: (l) => l.farmsCropStatusError);
      showToast(context, parsed.summary, tone: ToastTone.error);
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cropAsync = ref.watch(cropProvider(widget.cropId));
    final crop = cropAsync.value;
    return Scaffold(
      appBar: AgriLinkAppBar(
        title: crop == null ? l10n.farmsFieldCrops : cropLabel(l10n, crop.cropType),
      ),
      body: AsyncValueView(
        value: cropAsync,
        onRetry: () => ref.invalidate(cropProvider(widget.cropId)),
        data: (crop) => RefreshIndicator(onRefresh: _refresh, child: _content(crop)),
      ),
    );
  }

  Widget _content(Crop crop) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final format = ref.watch(formattersProvider);
    return ListView(
      padding: const EdgeInsets.all(Gaps.md),
      children: [
        Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: colors.tint(colors.forest), shape: BoxShape.circle),
              child: SizedBox.square(
                dimension: 56,
                child: Center(child: CropIcon(crop.cropType, size: 32)),
              ),
            ),
            const SizedBox(width: Gaps.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cropLabel(l10n, crop.cropType), style: textTheme.headlineSmall),
                  Text(
                    crop.variety.isEmpty ? l10n.farmsCropNoVariety : crop.variety,
                    style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Gaps.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gaps.md),
            child: Column(
              children: [
                _DetailRow(l10n.farmsCropPlantingDate, format.date(crop.plantingDate)),
                _DetailRow(l10n.farmsCropExpectedHarvest, format.date(crop.expectedHarvestDate)),
                _DetailRow(
                  l10n.farmsCropExpectedQuantity,
                  format.kilograms(l10n, crop.expectedQuantity),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gaps.lg),
        Semantics(header: true, child: Text(l10n.commonFieldsStatus, style: textTheme.titleMedium)),
        const SizedBox(height: Gaps.sm),
        Wrap(
          spacing: Gaps.sm,
          runSpacing: Gaps.sm,
          children: [
            for (final status in CropStatus.values)
              ChoiceChip(
                key: Key('status-${status.apiName}'),
                label: Text(statusLabel(l10n, StatusKind.crop, status.apiName)),
                selected: crop.status == status,
                showCheckmark: true,
                // Only another status is a change; the current one stays put.
                onSelected: _updating || crop.status == status
                    ? null
                    : (_) => _changeStatus(crop, status),
              ),
          ],
        ),
      ],
    );
  }
}

/// A label on the left and its value on the right.
class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary),
            ),
          ),
          const SizedBox(width: Gaps.md),
          Flexible(
            child: Text(value, textAlign: TextAlign.end, style: textTheme.bodyLarge!.mono),
          ),
        ],
      ),
    );
  }
}
