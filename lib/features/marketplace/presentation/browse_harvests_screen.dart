import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/marketplace_providers.dart';
import '../marketplace_paths.dart';
import 'widgets/harvest_card.dart';
import 'widgets/harvest_filter_sheet.dart';
import 'widgets/list_skeleton.dart';

/// The marketplace: every active listing, newest first, like the website's BrowseHarvestsPage.
/// Farmers, buyers and admins all see it; tapping a listing opens it.
class BrowseHarvestsScreen extends ConsumerStatefulWidget {
  const BrowseHarvestsScreen({super.key});

  @override
  ConsumerState<BrowseHarvestsScreen> createState() => _BrowseHarvestsScreenState();
}

class _BrowseHarvestsScreenState extends ConsumerState<BrowseHarvestsScreen> {
  HarvestFilters _filters = HarvestFilters.none;

  Future<void> _openFilters() async {
    final picked = await showHarvestFilterSheet(context, _filters);
    if (picked != null && mounted) {
      setState(() => _filters = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = browseListingsProvider(_filters.server);
    final listings = ref.watch(provider);
    final filterCount = _filters.count;

    return Scaffold(
      appBar: AgriLinkAppBar(
        title: l10n.commonNavMarketplace,
        actions: [
          IconButton(
            key: const Key('open-filters'),
            tooltip: l10n.marketplaceFiltersTitle,
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: filterCount > 0,
              label: Text('$filterCount'),
              child: const Icon(Icons.tune),
            ),
          ),
        ],
      ),
      body: switch (listings) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(provider.future),
          child: Builder(
            builder: (context) {
              final visible = _filters.priceRange.apply(value);
              if (visible.isEmpty) {
                return EmptyView(
                  icon: Icons.storefront_outlined,
                  title: l10n.marketplaceBrowseEmpty,
                  action: filterCount > 0
                      ? OutlinedButton(
                          onPressed: () => setState(() => _filters = HarvestFilters.none),
                          child: Text(l10n.marketplaceFiltersClear),
                        )
                      : null,
                );
              }
              return ListView.separated(
                key: const Key('harvest-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(Gaps.md),
                itemCount: visible.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: Gaps.sm + 4),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Text(
                      l10n.marketplaceBrowseSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: context.colors.textSecondary),
                    );
                  }
                  final listing = visible[index - 1];
                  return HarvestCard(
                    listing: listing,
                    onTap: () => context.push(MarketplacePaths.listing(listing.id)),
                  );
                },
              );
            },
          ),
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(provider),
        ),
        _ => const ListSkeleton(),
      },
    );
  }
}
