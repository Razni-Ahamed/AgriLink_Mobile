import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/shell/agrilink_app_bar.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/labels.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/marketplace_errors.dart';
import '../application/marketplace_providers.dart';
import '../data/marketplace_api.dart';
import '../data/marketplace_enums.dart';
import '../data/purchase_request.dart';
import '../marketplace_paths.dart';
import 'widgets/grouped_by_status.dart';
import 'widgets/list_skeleton.dart';
import 'widgets/purchase_request_card.dart';

/// The requests the buyer has sent, like the website's MySentPurchaseRequestsPage. Tapping one
/// opens its listing. An accepted request becomes an order, found under Orders. A pending one
/// can be withdrawn.
class SentRequestsScreen extends ConsumerStatefulWidget {
  const SentRequestsScreen({super.key});

  @override
  ConsumerState<SentRequestsScreen> createState() => _SentRequestsScreenState();
}

class _SentRequestsScreenState extends ConsumerState<SentRequestsScreen> {
  /// The request being withdrawn.
  int? _withdrawingId;

  Future<void> _withdraw(PurchaseRequest request) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.marketplaceSentRequestsWithdrawConfirmTitle,
      message: l10n.marketplaceSentRequestsWithdrawConfirmBody,
      confirmLabel: l10n.marketplaceSentRequestsWithdraw,
      cancelLabel: l10n.marketplaceSentRequestsKeep,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _withdrawingId = request.id);
    try {
      await ref.read(marketplaceApiProvider).withdraw(request.id);
      if (mounted) {
        showToast(context, l10n.marketplaceSentRequestsWithdrawn, tone: ToastTone.success);
      }
    } on Object catch (error) {
      if (mounted) {
        // The farmer may have answered in the meantime; the server says so.
        final parsed = parseMarketplaceError(
          error,
          l10n,
          (l) => l.marketplaceSentRequestsWithdrawError,
        );
        showToast(context, parsed.summary, tone: ToastTone.error);
      }
    } finally {
      refreshTrade(ref);
      if (mounted) {
        setState(() => _withdrawingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.marketplaceSentRequestsTitle),
      body: switch (ref.watch(sentRequestsProvider)) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(sentRequestsProvider.future),
          child: value.isEmpty
              ? EmptyView(
                  icon: Icons.assignment_outlined,
                  title: l10n.marketplaceSentRequestsEmpty,
                  message: l10n.marketplaceSentRequestsEmptyHint,
                  action: OutlinedButton(
                    onPressed: () => context.go(AppRoutes.marketplace),
                    child: Text(l10n.marketplaceSentRequestsBrowseMarketplace),
                  ),
                )
              : GroupedByStatus<PurchaseRequest, PurchaseRequestStatus>(
                  key: const Key('sent-requests'),
                  items: value,
                  order: PurchaseRequestStatus.values,
                  statusOf: (request) => request.status,
                  labelOf: (status) => statusLabel(l10n, StatusKind.request, status.apiName),
                  itemBuilder: (context, request) => PurchaseRequestCard(
                    request: request,
                    onTap: () => context.push(MarketplacePaths.listing(request.harvestId)),
                    onWithdraw: () => _withdraw(request),
                    responding: _withdrawingId == request.id,
                  ),
                ),
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(sentRequestsProvider),
        ),
        _ => const ListSkeleton(),
      },
    );
  }
}
