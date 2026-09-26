import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/format/formatters.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/labels.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/marketplace_providers.dart';
import '../data/harvest_listing.dart';
import '../data/marketplace_enums.dart';
import '../marketplace_paths.dart';
import 'widgets/edit_listing_sheet.dart';
import 'widgets/harvest_card.dart';
import 'widgets/list_skeleton.dart';
import 'widgets/new_listing_sheet.dart';
import 'widgets/status_filter_chips.dart';

/// The farmer's own listings in every status, like the website's MyListingsPage, with a
/// "New Listing" button and a quick edit on each.
class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  HarvestStatus? _status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final listings = ref.watch(myListingsProvider);

    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.marketplaceListingsTitle),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-listing'),
        onPressed: () => showNewListingSheet(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.marketplaceListingsNewListing),
      ),
      body: switch (listings) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(myListingsProvider.future),
          child: value.isEmpty
              ? EmptyView(
                  icon: Icons.shopping_basket_outlined,
                  title: l10n.marketplaceListingsEmpty,
                  message: l10n.marketplaceListingsEmptyHint,
                )
              : _ListingList(
                  listings: value,
                  status: _status,
                  onStatus: (status) => setState(() => _status = status),
                ),
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(myListingsProvider),
        ),
        _ => const ListSkeleton(),
      },
    );
  }
}

class _ListingList extends ConsumerWidget {
  const _ListingList({required this.listings, required this.status, required this.onStatus});

  final List<HarvestListing> listings;
  final HarvestStatus? status;
  final ValueChanged<HarvestStatus?> onStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final visible = [
      for (final listing in listings)
        if (status == null || listing.status == status) listing,
    ];

    return ListView(
      key: const Key('my-listings'),
      physics: const AlwaysScrollableScrollPhysics(),
      // Room at the bottom so the last card isn't hidden behind the button.
      padding: const EdgeInsets.only(top: Gaps.md, bottom: 96),
      children: [
        StatusFilterChips<HarvestStatus>(
          statuses: HarvestStatus.values,
          counts: countByStatus(listings, (HarvestListing listing) => listing.status),
          labelOf: (s) => statusLabel(l10n, StatusKind.harvest, s.apiName),
          selected: status,
          onSelected: onStatus,
        ),
        const SizedBox(height: Gaps.sm + 4),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Gaps.lg),
            child: Text(
              l10n.marketplaceStatusFilterEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.colors.textSecondary),
            ),
          ),
        for (final listing in visible)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gaps.md, 0, Gaps.md, Gaps.sm + 4),
            child: HarvestCard(
              listing: listing,
              onTap: () => context.push(MarketplacePaths.listing(listing.id)),
              trailing: _OwnerFooter(listing: listing),
            ),
          ),
      ],
    );
  }
}

/// Under each of the farmer's cards: how much of the harvest is left, and a quick edit.
class _OwnerFooter extends ConsumerWidget {
  const _OwnerFooter({required this.listing});

  final HarvestListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = ref.watch(formattersProvider);
    return Padding(
      padding: const EdgeInsets.only(top: Gaps.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.marketplaceListingsAvailableOf(
                format.number(listing.availableQuantity),
                format.kilograms(l10n, listing.quantity),
              ),
              style: Theme.of(context).textTheme.bodySmall!.mono
                  .copyWith(color: context.colors.textSecondary),
            ),
          ),
          TextButton.icon(
            key: Key('quick-edit-${listing.id}'),
            onPressed: () => showEditListingSheet(context, listing),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(l10n.commonActionsEdit),
          ),
        ],
      ),
    );
  }
}
