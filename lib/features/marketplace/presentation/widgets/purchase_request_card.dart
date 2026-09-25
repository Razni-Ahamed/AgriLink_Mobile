import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/format/formatters.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/labels.dart';
import '../../../../shared/widgets/crop_icon.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/marketplace_enums.dart';
import '../../data/purchase_request.dart';
import 'header_badge.dart';

/// One purchase request, like the website's PurchaseRequestCard. With [onAccept] and
/// [onDecline] (the farmer's incoming requests) a pending request shows the two buttons;
/// without them (the buyer's sent requests) it only reads.
class PurchaseRequestCard extends ConsumerWidget {
  const PurchaseRequestCard({
    super.key,
    required this.request,
    required this.onTap,
    this.showBuyer = false,
    this.onAccept,
    this.onDecline,
    this.responding = false,
  });

  final PurchaseRequest request;

  /// Opens the listing the request is for.
  final VoidCallback onTap;

  /// Whether to say who sent it: the farmer needs to know, the buyer already does.
  final bool showBuyer;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  /// While the farmer's answer is being sent: both buttons wait.
  final bool responding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = ref.watch(formattersProvider);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final secondary = text.bodyMedium?.copyWith(color: colors.textSecondary);
    final canRespond =
        request.status == PurchaseRequestStatus.pending && onAccept != null && onDecline != null;

    return Card(
      key: Key('request-${request.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gaps.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CropIcon(request.cropType, size: 28),
                  const SizedBox(width: Gaps.sm + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cropLabel(l10n, request.cropType), style: text.titleLarge),
                        Text(
                          l10n.marketplaceRequestsRequestNumber(request.id),
                          style: text.bodySmall!.mono.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Gaps.sm),
                  HeaderBadge(
                    child: StatusBadge.status(StatusKind.request, request.status.apiName),
                  ),
                ],
              ),
              const SizedBox(height: Gaps.sm + 4),
              if (showBuyer) ...[
                Text(l10n.marketplaceRequestsFrom(_buyer(request)), style: secondary),
                const SizedBox(height: Gaps.xs),
              ],
              Text(
                format.kilograms(l10n, request.requestedQuantity),
                style: text.titleMedium!.mono.copyWith(color: colors.forest),
              ),
              Text(
                '${l10n.commonUnitsRupeesPerUnit(format.number(request.pricePerUnit))}'
                ' · ${request.district}',
                style: text.bodyMedium!.mono.copyWith(color: colors.textSecondary),
              ),
              Text(
                '${l10n.marketplaceListingFormEstimatedTotal}: ${format.rupees(l10n, request.total)}',
                style: text.bodyMedium!.mono,
              ),
              if (request.message.isNotEmpty) ...[
                const SizedBox(height: Gaps.sm),
                Text('“${request.message}”', style: secondary),
              ],
              const SizedBox(height: Gaps.sm),
              Text(
                format.date(request.createdAt),
                style: text.bodySmall?.copyWith(color: colors.textSecondary),
              ),
              if (canRespond) ...[
                const SizedBox(height: Gaps.sm + 4),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        key: Key('accept-${request.id}'),
                        onPressed: responding ? null : onAccept,
                        child: Text(l10n.commonActionsAccept),
                      ),
                    ),
                    const SizedBox(width: Gaps.sm + 4),
                    Expanded(
                      child: OutlinedButton(
                        key: Key('decline-${request.id}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.danger,
                          side: BorderSide(color: colors.danger),
                        ),
                        onPressed: responding ? null : onDecline,
                        child: Text(l10n.commonActionsDecline),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Nimal Silva · Silva Traders", as the website names who sent a request.
String _buyer(PurchaseRequest request) => request.buyerBusinessName.isEmpty
    ? request.buyerName
    : '${request.buyerName} · ${request.buyerBusinessName}';

/// The buyer as the confirmation dialogs name them: the business if there is one.
String requestBuyerName(PurchaseRequest request) =>
    request.buyerBusinessName.isEmpty ? request.buyerName : request.buyerBusinessName;
