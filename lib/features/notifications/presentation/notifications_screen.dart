import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/format/formatters.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/permissions/permissions.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/paged_list.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/notification_permission.dart';
import '../application/unread_count.dart';
import '../data/notifications_api.dart';

/// The user's notifications, newest first, loading more on scroll. Tapping one marks it read;
/// "Mark all read" marks them all.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late final PagedListController<AppNotification> _list = PagedListController(
    loadPage: (page) => ref.read(notificationsApiProvider).mine(page: page),
  );
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    // The badge should match what the list is about to show.
    Future.microtask(() => ref.read(unreadCountProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  Future<void> _markRead(AppNotification notification) async {
    if (notification.isRead) {
      return;
    }
    // Show it as read straight away; put it back if the server refuses.
    _list.updateWhere((n) => n.id == notification.id, (n) => n.markedRead());
    final unread = ref.read(unreadCountProvider.notifier);
    unread.setCount(ref.read(unreadCountProvider) - 1);
    try {
      await ref.read(notificationsApiProvider).markRead(notification.id);
    } on Object {
      _list.updateWhere((n) => n.id == notification.id, (_) => notification);
      if (mounted) {
        showToast(context, context.l10n.commonErrorsGeneric, tone: ToastTone.error);
      }
    }
    await unread.refresh();
  }

  Future<void> _markAllRead() async {
    setState(() => _markingAll = true);
    try {
      await ref.read(notificationsApiProvider).markAllRead();
      _list.updateWhere((n) => !n.isRead, (n) => n.markedRead());
      ref.read(unreadCountProvider.notifier).setCount(0);
    } on Object {
      if (mounted) {
        showToast(context, context.l10n.commonErrorsGeneric, tone: ToastTone.error);
      }
    } finally {
      if (mounted) {
        setState(() => _markingAll = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unread = ref.watch(unreadCountProvider);
    return Scaffold(
      appBar: AgriLinkAppBar(
        title: l10n.ordersNotificationsTitle,
        actions: [
          if (unread > 0)
            IconButton(
              key: const Key('mark-all-read'),
              tooltip: l10n.commonActionsMarkAllRead,
              onPressed: _markingAll ? null : _markAllRead,
              icon: const Icon(Icons.done_all),
            ),
        ],
      ),
      body: Column(
        children: [
          const _TurnOnBanner(),
          Expanded(
            child: PagedListView<AppNotification>(
              controller: _list,
              empty: EmptyView(
                icon: Icons.notifications_none_outlined,
                title: l10n.ordersNotificationsEmpty,
              ),
              itemBuilder: (context, notification, _) => _NotificationTile(
                notification: notification,
                onTap: () => _markRead(notification),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final format = ref.watch(formattersProvider);
    final unread = !notification.isRead;
    return Semantics(
      button: unread,
      label: unread ? l10n.ordersNotificationsUnread : null,
      child: Card(
        color: unread ? colors.tint(colors.forest) : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Gaps.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 12),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: unread ? colors.terracotta : Colors.transparent,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(notification.message, style: textTheme.bodyMedium),
                      const SizedBox(height: Gaps.xs),
                      Text(format.dateTime(notification.createdAt), style: textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown while pop-ups aren't allowed, with a button to allow them.
class _TurnOnBanner extends ConsumerWidget {
  const _TurnOnBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(notificationPermissionProvider).value;
    if (status == null || status == PermissionResult.granted) {
      return const SizedBox.shrink();
    }
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.sm, Gaps.md, 0),
      child: Card(
        color: colors.tint(colors.info),
        child: Padding(
          padding: const EdgeInsets.all(Gaps.md),
          child: Row(
            children: [
              Icon(Icons.notifications_active_outlined, color: colors.info),
              const SizedBox(width: Gaps.md),
              Expanded(child: Text(l10n.commonPermissionsNotificationsRationale)),
              TextButton(
                key: const Key('turn-on-notifications'),
                onPressed: () async {
                  final permissions = ref.read(permissionServiceProvider);
                  if (status == PermissionResult.permanentlyDenied) {
                    await permissions.openSettings();
                  } else {
                    await permissions.request(AppPermission.notifications);
                  }
                  ref.invalidate(notificationPermissionProvider);
                },
                child: Text(l10n.commonPermissionsTurnOn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
