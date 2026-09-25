import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/api/api_error_parser.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/farms.dart';
import '../farmer_paths.dart';
import 'widgets/farm_form.dart';
import 'widgets/farmer_cards.dart';

/// The farmer's farms: a card for each, pull to refresh, and a button to add one.
class FarmsScreen extends ConsumerWidget {
  const FarmsScreen({super.key});

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    try {
      ref.invalidate(myFarmsProvider);
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
    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.farmsListTitle),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-farm'),
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.farmsListNewFarm),
      ),
      body: AsyncValueView(
        value: ref.watch(myFarmsProvider),
        onRetry: () => ref.invalidate(myFarmsProvider),
        data: (farms) => RefreshIndicator(
          onRefresh: () => _refresh(context, ref),
          child: farms.isEmpty
              ? EmptyView(
                  icon: Icons.agriculture_outlined,
                  title: l10n.farmsListEmpty,
                  action: FilledButton.icon(
                    onPressed: () => _add(context),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.farmsListNewFarm),
                  ),
                )
              : ListView.separated(
                  key: const Key('farms-list'),
                  // Room under the last card for the floating button.
                  padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.md, Gaps.md, 96),
                  itemCount: farms.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Gaps.sm),
                  itemBuilder: (context, index) {
                    final farm = farms[index];
                    return FarmCard(
                      key: Key('farm-${farm.id}'),
                      farm: farm,
                      onTap: () => context.go(FarmerPaths.farm(farm.id)),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
