import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/session/role.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/labels.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../data/order.dart';

/// One order in the list, like the website's OrderCard: its number and status, the person on
/// the other side, the crop, quantity, total and date.
class OrderCard extends ConsumerWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.viewerIsFarmer,
    required this.onTap,
  });

  final Order order;
  final bool viewerIsFarmer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = ref.watch(formattersProvider);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final other = order.otherParty(viewerIsFarmer: viewerIsFarmer);

    return Card(
      key: Key('order-${order.id}'),
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
                  Expanded(
                    child: Text(l10n.ordersCardOrderNumber(order.id), style: text.titleLarge),
                  ),
                  const SizedBox(width: Gaps.sm),
                  Flexible(child: StatusBadge.status(StatusKind.order, order.status.apiName)),
                ],
              ),
              const SizedBox(height: Gaps.sm),
              Row(
                children: [
                  UserAvatar(
                    role: viewerIsFarmer ? Role.buyer : Role.farmer,
                    name: other.name,
                    photoUrl: other.photoUrl,
                    size: 32,
                  ),
                  const SizedBox(width: Gaps.sm),
                  Expanded(
                    child: Text(
                      other.businessName == null
                          ? other.name
                          : '${other.name} · ${other.businessName}',
                      style: text.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gaps.sm),
              Text(
                cropLabel(l10n, order.cropType),
                style: text.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: Gaps.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      format.kilograms(l10n, order.totalQuantity),
                      style: text.bodyMedium!.mono.copyWith(color: colors.textSecondary),
                    ),
                  ),
                  Text(
                    format.rupees(l10n, order.totalAmount),
                    style: text.titleMedium!.mono.copyWith(color: colors.forest),
                  ),
                ],
              ),
              Text(
                format.date(order.orderDate),
                style: text.bodySmall!.mono.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
