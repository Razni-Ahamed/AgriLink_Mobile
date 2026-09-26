import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/api/api_error_parser.dart';
import '../../../core/format/formatters.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/labels.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/application/current_user.dart';
import '../application/admin_providers.dart';
import '../data/admin_api.dart';
import '../data/admin_models.dart';
import 'widgets/change_role_sheet.dart';
import 'widgets/edit_user_sheet.dart';
import 'widgets/reset_password_sheet.dart';
import 'widgets/sheet_frame.dart';
import 'widgets/user_card.dart';

/// One user and what an admin can do to them: edit their details, change their role, activate
/// or deactivate them, and reset their password. Every action that changes who can sign in, or
/// how, asks first and names the user.
///
/// The user comes from the same list the users screen shows, so once an action reloads that list
/// this page and the list both show the new state.
class UserDetailScreen extends ConsumerStatefulWidget {
  const UserDetailScreen({super.key, required this.userId});

  final int userId;

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  bool _busy = false;

  void _reload() => ref.invalidate(adminUsersProvider);

  Future<void> _edit(AdminUser user) async {
    final updated = await showFormSheet<AdminUser>(
      context,
      builder: (_) => EditUserSheet(user: user),
    );
    if (updated == null || !mounted) {
      return;
    }
    _reload();
    showToast(
      context,
      context.l10n.ordersAdminEditUserUpdated(updated.fullName),
      tone: ToastTone.success,
    );
  }

  Future<void> _changeRole(AdminUser user) async {
    final updated = await showFormSheet<AdminUser>(
      context,
      builder: (_) => ChangeRoleSheet(user: user),
    );
    if (updated == null || !mounted) {
      return;
    }
    _reload();
    final l10n = context.l10n;
    showToast(
      context,
      l10n.ordersAdminRoleUpdated(updated.fullName, roleLabel(l10n, updated.role.apiName)),
      tone: ToastTone.success,
    );
  }

  Future<void> _resetPassword(AdminUser user) async {
    final done = await showFormSheet<bool>(context, builder: (_) => ResetPasswordSheet(user: user));
    if (done != true || !mounted) {
      return;
    }
    showToast(
      context,
      context.l10n.ordersAdminPasswordReset(user.fullName),
      tone: ToastTone.success,
    );
  }

  Future<void> _toggleActive(AdminUser user) async {
    final l10n = context.l10n;
    final activate = !user.isActive;
    final confirmed = await showConfirmDialog(
      context,
      title: activate
          ? l10n.adminUsersDetailActivateConfirmTitle(user.fullName)
          : l10n.adminUsersDetailDeactivateConfirmTitle(user.fullName),
      message: activate
          ? l10n.adminUsersDetailActivateConfirmMessage(user.fullName)
          : l10n.adminUsersDetailDeactivateConfirmMessage(user.fullName),
      confirmLabel: activate ? l10n.ordersAdminActivate : l10n.ordersAdminDeactivate,
      destructive: !activate,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(adminApiProvider).setActive(user.userId, isActive: activate);
      _reload();
      if (mounted) {
        showToast(
          context,
          activate
              ? l10n.ordersAdminUserActivated(user.fullName)
              : l10n.ordersAdminUserDeactivated(user.fullName),
          tone: ToastTone.success,
        );
      }
    } on Object catch (error) {
      // Someone else may have changed it already ("User is already deactivated."): reload so the
      // page shows what is true now.
      _reload();
      if (mounted) {
        showToast(context, describeError(error, context.l10n), tone: ToastTone.error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final users = ref.watch(adminUsersProvider);
    final myId = ref.watch(currentUserProvider).value?.userId;
    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.adminUsersDetailTitle),
      body: AsyncValueView<List<AdminUser>>(
        value: users,
        onRetry: _reload,
        data: (list) {
          final user = list.where((u) => u.userId == widget.userId).firstOrNull;
          if (user == null) {
            return EmptyView(icon: Icons.person_off_outlined, title: l10n.adminUsersDetailNotFound);
          }
          return _Detail(
            user: user,
            isSelf: user.userId == myId,
            busy: _busy,
            onEdit: () => _edit(user),
            onChangeRole: () => _changeRole(user),
            onToggleActive: () => _toggleActive(user),
            onResetPassword: () => _resetPassword(user),
          );
        },
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({
    required this.user,
    required this.isSelf,
    required this.busy,
    required this.onEdit,
    required this.onChangeRole,
    required this.onToggleActive,
    required this.onResetPassword,
  });

  final AdminUser user;
  final bool isSelf;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onChangeRole;
  final VoidCallback onToggleActive;
  final VoidCallback onResetPassword;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final format = ref.watch(formattersProvider);
    final place = userPlace(user);
    return ListView(
      padding: const EdgeInsets.all(Gaps.md),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(Gaps.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  role: user.role,
                  name: user.fullName,
                  photoUrl: user.profilePhotoUrl,
                  size: 64,
                ),
                const SizedBox(width: Gaps.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: textTheme.titleLarge),
                      Text(
                        user.email,
                        style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                      ),
                      Text(
                        '@${user.username}',
                        style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                      ),
                      const SizedBox(height: Gaps.sm),
                      Wrap(
                        spacing: Gaps.sm,
                        runSpacing: Gaps.xs,
                        children: [
                          StatusBadge(
                            label: roleLabel(l10n, user.role.apiName),
                            tone: BadgeTone.info,
                          ),
                          ActiveBadge(isActive: user.isActive),
                        ],
                      ),
                      if (place != null) ...[
                        const SizedBox(height: Gaps.sm),
                        Text(place, style: textTheme.bodyMedium),
                      ],
                      const SizedBox(height: Gaps.xs),
                      Text(
                        l10n.adminUsersDetailJoined(format.date(user.createdAt)),
                        style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gaps.md),
        Text(l10n.ordersAdminActions, style: textTheme.titleMedium),
        const SizedBox(height: Gaps.sm),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              _Action(
                key: const Key('action-edit'),
                icon: Icons.edit_outlined,
                title: l10n.ordersAdminEditUser,
                onTap: busy ? null : onEdit,
              ),
              const Divider(height: 1),
              _Action(
                key: const Key('action-role'),
                icon: Icons.swap_horiz,
                title: l10n.ordersAdminChangeRole,
                // Farmers and admins can't be re-typed here; the reason is written out.
                note: user.canChangeRole ? null : l10n.adminUsersDetailCantChangeRole,
                onTap: busy || !user.canChangeRole ? null : onChangeRole,
              ),
              const Divider(height: 1),
              _Action(
                key: const Key('action-active'),
                icon: user.isActive ? Icons.block : Icons.check_circle_outline,
                title: user.isActive ? l10n.ordersAdminDeactivate : l10n.ordersAdminActivate,
                note: user.isAdmin ? l10n.adminUsersDetailAdminCantDeactivate : null,
                onTap: busy || user.isAdmin ? null : onToggleActive,
              ),
              const Divider(height: 1),
              _Action(
                key: const Key('action-password'),
                icon: Icons.lock_reset,
                title: l10n.ordersAdminResetPassword,
                // An admin uses Change password in their own profile for this.
                note: isSelf ? l10n.adminUsersDetailOwnAccountPassword : null,
                onTap: busy || isSelf ? null : onResetPassword,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One row of the actions card. A row that can't be used stays visible, greyed out, with the
/// reason written under it.
class _Action extends StatelessWidget {
  const _Action({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.note,
  });

  final IconData icon;
  final String title;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 56,
      leading: Icon(icon),
      title: Text(title),
      subtitle: note == null ? null : Text(note!),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      enabled: onTap != null,
      onTap: onTap,
    );
  }
}
