import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/api/api_error_parser.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/farms.dart';
import '../data/farm.dart';
import '../data/farms_api.dart';
import '../farmer_paths.dart';
import 'widgets/farm_form.dart';
import 'widgets/farmer_cards.dart';
import 'widgets/field_form.dart';
import 'widgets/inline_states.dart';

/// One farm: its details with edit and delete, and its fields, with a button to add one.
class FarmDetailScreen extends ConsumerStatefulWidget {
  const FarmDetailScreen({super.key, required this.farmId});

  final int farmId;

  @override
  ConsumerState<FarmDetailScreen> createState() => _FarmDetailScreenState();
}

class _FarmDetailScreenState extends ConsumerState<FarmDetailScreen> {
  bool _deleting = false;

  Future<void> _refresh() async {
    ref.invalidate(farmFieldsProvider(widget.farmId));
    try {
      ref.invalidate(myFarmsProvider);
      await ref.read(myFarmsProvider.future);
    } on Object catch (error) {
      if (mounted) {
        showToast(context, describeError(error, context.l10n), tone: ToastTone.error);
      }
    }
  }

  Future<void> _edit(Farm farm) async {
    final saved = await showFarmFormSheet(context, farm: farm);
    if (saved != null && mounted) {
      showToast(context, context.l10n.farmsDetailUpdated, tone: ToastTone.success);
    }
  }

  Future<void> _addField() async {
    final field = await showFieldFormSheet(context, farmId: widget.farmId);
    if (field != null && mounted) {
      showToast(context, context.l10n.farmsDetailFieldAdded, tone: ToastTone.success);
    }
  }

  Future<void> _delete(Farm farm) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.commonActionsDelete,
      message: l10n.farmsDetailDeleteConfirm,
      confirmLabel: l10n.commonActionsDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _deleting = true);
    try {
      await ref.read(farmsApiProvider).deleteFarm(farm.id);
      if (!mounted) {
        return;
      }
      ref.invalidate(myFarmsProvider);
      showToast(context, l10n.farmsDetailDeleted, tone: ToastTone.success);
      context.go(AppRoutes.farms);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _deleting = false);
      // A farm with crops can't be deleted, and the server says so in its own words.
      final parsed = parseApiError(error, l10n, generic: (l) => l.farmsDetailDeleteError);
      showToast(context, parsed.summary, tone: ToastTone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final farmAsync = ref.watch(farmProvider(widget.farmId));
    final farm = farmAsync.value;
    return Scaffold(
      appBar: AgriLinkAppBar(title: farm?.name ?? l10n.farmsListTitle),
      floatingActionButton: farm == null
          ? null
          : FloatingActionButton.extended(
              key: const Key('add-field'),
              onPressed: _addField,
              icon: const Icon(Icons.add),
              label: Text(l10n.farmsDetailAddField),
            ),
      body: AsyncValueView(
        value: farmAsync,
        onRetry: () => ref.invalidate(myFarmsProvider),
        data: (farm) => farm == null
            ? EmptyView(icon: Icons.search_off_outlined, title: l10n.farmsDetailNotFound)
            : RefreshIndicator(onRefresh: _refresh, child: _content(farm)),
      ),
    );
  }

  Widget _content(Farm farm) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final fields = ref.watch(farmFieldsProvider(farm.id));
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.md, Gaps.md, 96),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gaps.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(farm.name, style: textTheme.headlineSmall),
                const SizedBox(height: Gaps.xs),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: colors.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        farm.district,
                        style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gaps.xs),
                AcresText(farm.area, style: textTheme.titleMedium),
                const SizedBox(height: Gaps.md),
                Wrap(
                  spacing: Gaps.sm,
                  runSpacing: Gaps.sm,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('edit-farm'),
                      onPressed: _deleting ? null : () => _edit(farm),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(l10n.commonActionsEdit),
                    ),
                    OutlinedButton.icon(
                      key: const Key('delete-farm'),
                      onPressed: _deleting ? null : () => _delete(farm),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.danger,
                        side: BorderSide(color: colors.danger),
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l10n.commonActionsDelete),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gaps.lg),
        Semantics(header: true, child: Text(l10n.farmsDetailFields, style: textTheme.titleLarge)),
        const SizedBox(height: Gaps.sm),
        InlineAsyncView(
          value: fields,
          onRetry: () => ref.invalidate(farmFieldsProvider(farm.id)),
          data: (list) => list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gaps.sm),
                  child: Text(
                    l10n.farmsDetailNoFields,
                    style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                  ),
                )
              : Column(
                  children: [
                    for (final field in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gaps.sm),
                        child: FieldCard(
                          key: Key('field-${field.id}'),
                          field: field,
                          onTap: () => context.go(FarmerPaths.field(farm.id, field.id)),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
