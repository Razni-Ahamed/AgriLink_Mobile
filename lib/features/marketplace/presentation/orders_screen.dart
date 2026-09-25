import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/session/role.dart';
import '../../../core/session/session_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/labels.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/marketplace_providers.dart';
import '../data/marketplace_enums.dart';
import '../data/order.dart';
import '../marketplace_paths.dart';
import 'widgets/list_skeleton.dart';
import 'widgets/order_card.dart';
import 'widgets/status_filter_chips.dart';

/// The user's orders, newest first, as a farmer or a buyer, like the website's MyOrdersPage.
/// There are no links from notifications, so pull to refresh is how new orders appear.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  OrderStatus? _status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final viewerIsFarmer = ref.watch(sessionControllerProvider).role == Role.farmer;

    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.ordersListTitle),
      body: switch (ref.watch(myOrdersProvider)) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(myOrdersProvider.future),
          child: value.isEmpty
              ? EmptyView(icon: Icons.local_shipping_outlined, title: l10n.ordersListEmpty)
              : ListView(
                  key: const Key('orders'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: Gaps.md, bottom: Gaps.lg),
                  children: [
                    StatusFilterChips<OrderStatus>(
                      statuses: OrderStatus.values,
                      counts: countByStatus(value, (Order order) => order.status),
                      labelOf: (s) => statusLabel(l10n, StatusKind.order, s.apiName),
                      selected: _status,
                      onSelected: (status) => setState(() => _status = status),
                    ),
                    const SizedBox(height: Gaps.sm + 4),
                    ..._visible(context, value, viewerIsFarmer),
                  ],
                ),
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(myOrdersProvider),
        ),
        _ => const ListSkeleton(),
      },
    );
  }

  List<Widget> _visible(BuildContext context, List<Order> orders, bool viewerIsFarmer) {
    final visible = [
      for (final order in orders)
        if (_status == null || order.status == _status) order,
    ];
    if (visible.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(Gaps.lg),
          child: Text(
            context.l10n.marketplaceStatusFilterEmpty,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
        ),
      ];
    }
    return [
      for (final order in visible)
        Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.md, 0, Gaps.md, Gaps.sm + 4),
          child: OrderCard(
            order: order,
            viewerIsFarmer: viewerIsFarmer,
            onTap: () => context.push(MarketplacePaths.order(order.id)),
          ),
        ),
    ];
  }
}
