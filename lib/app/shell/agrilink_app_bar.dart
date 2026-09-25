import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/role.dart';
import '../../core/session/session_controller.dart';
import '../../features/auth/application/current_user.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/user_avatar.dart';
import '../router/app_routes.dart';

/// The app bar for every signed-in page: the title, the notification bell and the user's
/// avatar (which opens the profile). A page opened on top of another gets a back button.
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
        const NotificationBell(),
        const AvatarButton(),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// The bell in the app bar. Opens the notifications list.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('notification-bell'),
      tooltip: context.l10n.commonNavNotifications,
      icon: const Icon(Icons.notifications_outlined),
      onPressed: () => context.go(AppRoutes.notifications),
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
