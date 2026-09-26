import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/shell/agrilink_app_bar.dart';
import '../../../core/format/formatters.dart';
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

/// Requests buyers have sent for the farmer's listings, pending ones first, like the website's
/// MyPurchaseRequestsPage. Accepting creates an order; both answers are confirmed first.
class IncomingRequestsScreen extends ConsumerStatefulWidget {
  const IncomingRequestsScreen({super.key});

  @override
  ConsumerState<IncomingRequestsScreen> createState() => _IncomingRequestsScreenState();
}

class _IncomingRequestsScreenState extends ConsumerState<IncomingRequestsScreen> {
  /// The request whose answer is being sent.
  int? _respondingId;

  Future<void> _respond(PurchaseRequest request, RequestAction action) async {
    final l10n = context.l10n;
    final format = ref.read(formattersProvider);
    final quantity = format.kilograms(l10n, request.requestedQuantity);
    final crop = cropLabel(l10n, request.cropType);
    final buyer = requestBuyerName(request);
    final total = format.rupees(l10n, request.total);
    final accepting = action == RequestAction.accept;

    final confirmed = await showConfirmDialog(
      context,
      title: accepting
          ? l10n.marketplaceRequestsAcceptConfirmTitle
          : l10n.marketplaceRequestsDeclineConfirmTitle,
      message: accepting
          ? l10n.marketplaceRequestsAcceptConfirmBody(quantity, crop, buyer, total)
          : l10n.marketplaceRequestsDeclineConfirmBody(buyer, quantity, crop, total),
      confirmLabel: accepting ? l10n.commonActionsAccept : l10n.commonActionsDecline,
      destructive: !accepting,
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _respondingId = request.id);
    try {
      await ref.read(marketplaceApiProvider).respond(request.id, action);
      if (mounted) {
        showToast(
          context,
          accepting ? l10n.marketplaceRequestsAccepted : l10n.marketplaceRequestsDeclined,
          tone: ToastTone.success,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        // The server explains a refusal ("Not enough available quantity…"); show it as it is.
        final parsed = parseMarketplaceError(
          error,
          l10n,
          (l) => accepting ? l.marketplaceRequestsAcceptError : l.marketplaceRequestsDeclineError,
        );
        showToast(context, parsed.summary, tone: ToastTone.error);
      }
    } finally {
      // Refresh either way: after a refusal the request or listing has probably changed too.
      refreshTrade(ref);
      if (mounted) {
        setState(() => _respondingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.marketplaceRequestsTitle),
      body: switch (ref.watch(incomingRequestsProvider)) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(incomingRequestsProvider.future),
          child: value.isEmpty
              ? EmptyView(
                  icon: Icons.assignment_outlined,
                  title: l10n.marketplaceRequestsEmpty,
                  message: l10n.marketplaceRequestsEmptyHint,
                  action: OutlinedButton(
                    onPressed: () => context.go(AppRoutes.myListings),
                    child: Text(l10n.marketplaceRequestsGoToListings),
                  ),
                )
              : GroupedByStatus<PurchaseRequest, PurchaseRequestStatus>(
                  key: const Key('incoming-requests'),
                  items: value,
                  order: PurchaseRequestStatus.values,
                  statusOf: (request) => request.status,
                  labelOf: (status) => statusLabel(l10n, StatusKind.request, status.apiName),
                  itemBuilder: (context, request) => PurchaseRequestCard(
                    request: request,
                    showBuyer: true,
                    responding: _respondingId == request.id,
                    onTap: () => context.push(MarketplacePaths.listing(request.harvestId)),
                    onAccept: () => _respond(request, RequestAction.accept),
                    onDecline: () => _respond(request, RequestAction.decline),
                  ),
                ),
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(incomingRequestsProvider),
        ),
        _ => const ListSkeleton(),
      },
    );
  }
}
