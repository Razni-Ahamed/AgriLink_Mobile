import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/role.dart';
import '../../core/session/session_controller.dart';
import '../../features/auth/application/current_user.dart';
import '../../features/messages/application/chat_providers.dart';
import '../../features/messages/messages_paths.dart';
import '../../features/notifications/application/unread_count.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/user_avatar.dart';
import '../router/app_routes.dart';

/// The app bar for every signed-in page: the title, the chat button (farmers, buyers and
/// officers), the notification bell and the user's avatar (which opens the profile). A page
/// opened on top of another gets a back button.
///
/// ```dart
/// Scaffold(
///   appBar: AgriLinkAppBar(title: context.l10n.commonNavFarms),
///   body: ...,
/// )
/// ```
class AgriLinkAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AgriLinkAppBar({super.key, required this.title, this.actions = const [], this.bottom});

  final String title;

  /// Extra buttons, shown before the bell and avatar.
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      bottom: bottom,
      actions: [
        ...actions,
        const ChatButton(),
        const NotificationBell(),
        const AvatarButton(),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// The bell in the app bar, with the number of unread notifications. Opens the list.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final unread = ref.watch(unreadCountProvider);
    return IconButton(
      key: const Key('notification-bell'),
      tooltip: unread > 0 ? l10n.commonNavUnreadNotifications(unread) : l10n.commonNavNotifications,
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: Icon(unread > 0 ? Icons.notifications : Icons.notifications_outlined),
      ),
      onPressed: () => context.go(AppRoutes.notifications),
    );
  }
}

/// The chat button, with the number of unread messages. Opens the chat list. Hidden for
/// admins, who read reported chats on the website.
class ChatButton extends ConsumerWidget {
  const ChatButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(sessionControllerProvider.select((session) => session.role));
    if (!canChat(role)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final unread = ref.watch(chatUnreadCountProvider);
    return IconButton(
      key: const Key('chat-button'),
      tooltip: unread > 0
          ? '${l10n.messagesHeaderOpen}, '
                '${unread == 1 ? l10n.messagesHeaderUnreadOne(unread) : l10n.messagesHeaderUnreadOther(unread)}'
          : l10n.messagesHeaderOpen,
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: Icon(unread > 0 ? Icons.forum : Icons.forum_outlined),
      ),
      onPressed: () => context.go(MessagesPaths.list),
    );
  }
}

/// The signed-in user's avatar in the app bar. Opens the profile.
class AvatarButton extends ConsumerWidget {
  const AvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final role = user?.role ?? ref.watch(sessionControllerProvider).role ?? Role.farmer;
    final name = user?.shownName ?? '';
    return IconButton(
      key: const Key('avatar-button'),
      tooltip: context.l10n.commonProfileMenuButton(name),
      onPressed: () => context.go(AppRoutes.profile),
      icon: UserAvatar(role: role, name: name, photoUrl: user?.profilePhotoUrl, size: 32),
    );
  }
}
