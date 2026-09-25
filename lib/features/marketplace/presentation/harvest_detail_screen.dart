import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/format/formatters.dart';
import '../../../core/session/role.dart';
import '../../../core/session/session_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/labels.dart';
import '../../../shared/widgets/crop_icon.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/application/current_user.dart';
import '../application/listing_rules.dart';
import '../application/marketplace_providers.dart';
import '../data/harvest_listing.dart';
import '../data/marketplace_enums.dart';
import 'widgets/edit_listing_sheet.dart';
import 'widgets/header_badge.dart';
import 'widgets/purchase_request_sheet.dart';

/// One listing, like the website's HarvestDetailPage. What the viewer can do depends on who
/// they are: a buyer can ask to buy it while it's active, the farmer who listed it and admins
/// can edit it, and everyone else reads it.
class HarvestDetailScreen extends ConsumerWidget {
  const HarvestDetailScreen({super.key, required this.harvestId});

  /// Null when the path's id isn't a number; shown as "not found".
  final int? harvestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final id = harvestId;

    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.commonNavMarketplace),
      body: id == null
          ? _NotFound()
          : switch (ref.watch(listingProvider(id))) {
              AsyncData(:final value) => RefreshIndicator(
                onRefresh: () => ref.refresh(listingProvider(id).future),
                child: _ListingDetail(listing: value),
              ),
              AsyncError(:final error)
                  when error is ApiException && error.kind == ApiErrorKind.notFound =>
                _NotFound(),
              AsyncError(:final error) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(listingProvider(id)),
              ),
              _ => const LoadingView(),
            },
    );
  }
}

class _NotFound extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      EmptyView(icon: Icons.search_off, title: context.l10n.marketplaceDetailNotFound);
}

class _ListingDetail extends ConsumerWidget {
  const _ListingDetail({required this.listing});

  final HarvestListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = ref.watch(formattersProvider);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final role = ref.watch(sessionControllerProvider).role;
    final farmerProfileId = ref.watch(currentUserProvider).value?.farmerProfileId;

    final isOwner = role == Role.farmer && isOwnListing(listing, farmerProfileId);
    final isAdmin = role == Role.admin;
    final canBuy = role == Role.buyer && listing.status == HarvestStatus.active;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Gaps.md),
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
                padding: const EdgeInsets.all(12),
                child: CropIcon(listing.cropType, size: 32),
              ),
            ),
            const SizedBox(width: Gaps.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cropLabel(l10n, listing.cropType), style: text.headlineSmall),
                  Text(
                    listing.variety.isEmpty ? l10n.marketplaceDetailNoVariety : listing.variety,
                    style: text.bodyMedium?.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gaps.sm),
            HeaderBadge(child: StatusBadge.status(StatusKind.harvest, listing.status.apiName)),
          ],
        ),
        const SizedBox(height: Gaps.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gaps.md, vertical: Gaps.sm),
            child: Column(
              children: [
                _Fact(
                  icon: Icons.sell_outlined,
                  label: l10n.marketplaceDetailPricePerUnit,
                  value: format.rupees(l10n, listing.pricePerUnit),
                  emphasise: true,
                ),
                _Fact(
                  icon: Icons.scale_outlined,
                  label: l10n.marketplaceDetailAvailableQuantity,
                  value: format.kilograms(l10n, listing.availableQuantity),
                  mono: true,
                ),
                _Fact(
                  icon: Icons.map_outlined,
                  label: l10n.marketplaceDetailDistrict,
                  value: listing.district,
                ),
                _Fact(
                  icon: Icons.place_outlined,
                  label: l10n.marketplaceDetailLocation,
                  value: listing.location,
                ),
                _Fact(
                  icon: Icons.event_outlined,
                  label: l10n.marketplaceDetailHarvestDate,
                  value: format.date(listing.harvestDate),
                  last: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gaps.lg),
        if (canBuy)
          FilledButton.icon(
            key: const Key('request-to-buy'),
            onPressed: () => showPurchaseRequestSheet(context, listing),
            icon: const Icon(Icons.shopping_cart_outlined),
            label: Text(l10n.marketplaceDetailRequestPurchase),
          )
        else if (role == Role.buyer)
          InfoBanner(message: l10n.marketplaceDetailUnavailable),
        if (isOwner || isAdmin)
          OutlinedButton.icon(
            key: const Key('edit-listing'),
            onPressed: () => showEditListingSheet(context, listing, asAdmin: isAdmin),
            icon: const Icon(Icons.edit_outlined),
            label: Text(l10n.marketplaceEditFormEditListing),
          ),
      ],
    );
  }
}

/// One labelled line of the listing's details.
class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasise = false,
    this.mono = false,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// The price: larger and green, as on the website.
  final bool emphasise;
  final bool mono;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    var valueStyle = emphasise ? text.titleMedium!.mono : text.bodyLarge!;
    if (mono) {
      valueStyle = valueStyle.mono;
    }
    if (emphasise) {
      valueStyle = valueStyle.copyWith(color: colors.forest);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: Gaps.sm + 4),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.textSecondary),
          const SizedBox(width: Gaps.sm + 4),
          Expanded(
            child: Text(label, style: text.bodyMedium?.copyWith(color: colors.textSecondary)),
          ),
          const SizedBox(width: Gaps.sm),
          Flexible(
            child: Text(value, style: valueStyle, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
