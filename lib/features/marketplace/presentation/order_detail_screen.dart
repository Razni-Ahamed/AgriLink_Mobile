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
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../application/contact_launcher.dart';
import '../application/marketplace_errors.dart';
import '../application/marketplace_providers.dart';
import '../data/marketplace_api.dart';
import '../data/order.dart';

/// One order, like the website's OrderDetailPage: the summary, the other party's contact
/// details (tap to call or email), and, while it is still confirmed, completing or cancelling it.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  /// Null when the path's id isn't a number; shown as "not found".
  final int? orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final id = orderId;

    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.commonNavOrders),
      body: id == null
          ? const _NotFound()
          : switch (ref.watch(orderProvider(id))) {
              AsyncData(:final value) => RefreshIndicator(
                onRefresh: () => ref.refresh(orderProvider(id).future),
                child: _OrderDetail(order: value),
              ),
              AsyncError(:final error)
                  when error is ApiException &&
                      (error.kind == ApiErrorKind.notFound ||
                          error.kind == ApiErrorKind.forbidden) =>
                const _NotFound(),
              AsyncError(:final error) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(orderProvider(id)),
              ),
              _ => const LoadingView(),
            },
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) =>
      EmptyView(icon: Icons.search_off, title: context.l10n.ordersDetailNotFound);
}

class _OrderDetail extends ConsumerStatefulWidget {
  const _OrderDetail({required this.order});

  final Order order;

  @override
  ConsumerState<_OrderDetail> createState() => _OrderDetailState();
}

enum _OrderAction { complete, cancel }

class _OrderDetailState extends ConsumerState<_OrderDetail> {
  _OrderAction? _busy;

  Future<void> _change(_OrderAction action) async {
    final l10n = context.l10n;
    final completing = action == _OrderAction.complete;
    final confirmed = await showConfirmDialog(
      context,
      title: completing ? l10n.ordersDetailMarkCompleted : l10n.ordersDetailCancelOrder,
      message: completing ? l10n.ordersDetailCompleteConfirm : l10n.ordersDetailCancelConfirm,
      confirmLabel: completing ? l10n.ordersDetailMarkCompleted : l10n.ordersDetailCancelOrder,
      cancelLabel: completing ? null : l10n.ordersDetailKeepOrder,
      destructive: !completing,
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _busy = action);
    final api = ref.read(marketplaceApiProvider);
    try {
      await (completing ? api.completeOrder(widget.order.id) : api.cancelOrder(widget.order.id));
      if (mounted) {
        showToast(
          context,
          completing ? l10n.ordersDetailCompleted : l10n.ordersDetailCancelled,
          tone: ToastTone.success,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        // E.g. the other party finished it first: "Only confirmed orders can be…".
        final parsed = parseMarketplaceError(error, l10n, (l) => l.ordersDetailTransitionError);
        showToast(context, parsed.summary, tone: ToastTone.error);
      }
    } finally {
      // Show the server's current state either way; cancelling also changes the listing.
      refreshTrade(ref);
      if (mounted) {
        setState(() => _busy = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = ref.watch(formattersProvider);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final order = widget.order;
    final viewerIsFarmer = ref.watch(sessionControllerProvider).role == Role.farmer;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Gaps.md),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.ordersCardOrderNumber(order.id), style: text.headlineSmall),
                  Text(
                    l10n.ordersDetailPlacedOn(format.date(order.orderDate)),
                    style: text.bodyMedium?.copyWith(color: colors.textSecondary),
                  ),
                  if (order.completedAt != null)
                    Text(
                      l10n.ordersDetailCompletedOn(format.date(order.completedAt!)),
                      style: text.bodyMedium?.copyWith(color: colors.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: Gaps.sm),
            Flexible(child: StatusBadge.status(StatusKind.order, order.status.apiName)),
          ],
        ),
        const SizedBox(height: Gaps.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gaps.md),
            child: Column(
              children: [
                _Line(
                  label: l10n.ordersDetailCrop,
                  value: cropLabel(l10n, order.cropType),
                  leading: CropIcon(order.cropType, size: 20),
                ),
                _Line(
                  label: l10n.ordersDetailQuantity,
                  value: format.kilograms(l10n, order.totalQuantity),
                  mono: true,
                ),
                _Line(
                  label: l10n.ordersDetailPricePerUnit,
                  value: l10n.commonUnitsRupeesPerUnit(format.number(order.pricePerUnit)),
                  mono: true,
                ),
                _Line(label: l10n.ordersDetailLocation, value: order.harvestLocation),
                const Divider(),
                _Line(
                  label: l10n.ordersDetailTotalAmount,
                  value: format.rupees(l10n, order.totalAmount),
                  mono: true,
                  emphasise: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gaps.lg),
        Semantics(header: true, child: Text(l10n.ordersDetailContact, style: text.titleLarge)),
        const SizedBox(height: Gaps.sm),
        _ContactCard(
          title: viewerIsFarmer ? l10n.ordersDetailBuyer : l10n.ordersDetailFarmer,
          role: viewerIsFarmer ? Role.buyer : Role.farmer,
          party: order.otherParty(viewerIsFarmer: viewerIsFarmer),
        ),
        if (order.status.canChange) ...[
          const SizedBox(height: Gaps.lg),
          FilledButton.icon(
            key: const Key('complete-order'),
            onPressed: _busy == null ? () => _change(_OrderAction.complete) : null,
            icon: _busy == _OrderAction.complete
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(l10n.ordersDetailMarkCompleted),
          ),
          const SizedBox(height: Gaps.sm),
          OutlinedButton.icon(
            key: const Key('cancel-order'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.danger,
              side: BorderSide(color: colors.danger),
            ),
            onPressed: _busy == null ? () => _change(_OrderAction.cancel) : null,
            icon: _busy == _OrderAction.cancel
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cancel_outlined),
            label: Text(l10n.ordersDetailCancelOrder),
          ),
        ],
      ],
    );
  }
}

/// One labelled line of the order summary.
class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.leading,
    this.mono = false,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final Widget? leading;
  final bool mono;

  /// The total: larger and green.
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    var style = emphasise ? text.titleMedium! : text.bodyLarge!;
    if (mono) {
      style = style.mono;
    }
    if (emphasise) {
      style = style.copyWith(color: colors.forest);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gaps.xs + 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: text.bodyMedium?.copyWith(color: colors.textSecondary)),
          ),
          if (leading != null) ...[leading!, const SizedBox(width: Gaps.xs + 2)],
          Flexible(
            child: Text(value, style: style, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

/// The other party: their photo, name (and business), district, and a tap to call or email.
class _ContactCard extends ConsumerWidget {
  const _ContactCard({required this.title, required this.role, required this.party});

  final String title;
  final Role role;
  final OrderParty party;

  Future<void> _open(BuildContext context, Future<bool> Function() launch) async {
    final opened = await launch();
    if (!opened && context.mounted) {
      showToast(context, context.l10n.ordersDetailCannotOpen, tone: ToastTone.error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final launcher = ref.watch(contactLauncherProvider);
    final phone = party.phone;
    final email = party.email;

    return Card(
      key: const Key('contact-card'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gaps.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: UserAvatar(role: role, name: party.name, photoUrl: party.photoUrl),
              title: Text(party.name, style: text.titleMedium),
              subtitle: Text(
                [?party.businessName, party.district, title].join(' · '),
                style: text.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
            ),
            if (phone != null)
              ListTile(
                key: const Key('contact-phone'),
                leading: Icon(Icons.phone_outlined, color: colors.forest),
                title: Text(phone, style: text.bodyLarge!.mono.copyWith(color: colors.forest)),
                subtitle: Text(l10n.ordersDetailPhone),
                // Also read out by screen readers, so they say what the tap does.
                trailing: Tooltip(
                  message: l10n.ordersDetailCall(party.displayName),
                  child: Icon(Icons.call, color: colors.forest),
                ),
                onTap: () => _open(context, () => launcher.call(phone)),
              )
            else
              ListTile(
                key: const Key('contact-no-phone'),
                leading: Icon(Icons.phone_disabled_outlined, color: colors.textSecondary),
                title: Text(
                  l10n.ordersDetailNoPhoneOnFile,
                  style: text.bodyMedium?.copyWith(color: colors.textSecondary),
                ),
              ),
            if (email != null)
              ListTile(
                key: const Key('contact-email'),
                leading: Icon(Icons.email_outlined, color: colors.forest),
                title: Text(email, style: text.bodyLarge?.copyWith(color: colors.forest)),
                subtitle: Text(l10n.ordersDetailEmail),
                trailing: Tooltip(
                  message: l10n.ordersDetailEmailTo(party.displayName),
                  child: Icon(Icons.send_outlined, color: colors.forest),
                ),
                onTap: () => _open(context, () => launcher.email(email)),
              ),
          ],
        ),
      ),
    );
  }
}
