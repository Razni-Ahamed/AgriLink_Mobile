import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/theme/theme_mode_controller.dart';
import '../../../core/format/formatters.dart';
import '../../../core/session/role.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/labels.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/language_switcher.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/theme_mode_button.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/application/auth_service.dart';
import '../../auth/application/current_user.dart';
import '../../auth/data/auth_models.dart';

/// The signed-in user's profile: everything the account holds (with a note on where each
/// detail can be changed), the language and theme settings, and log out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.authProfileTitle),
      body: AsyncValueView(
        value: ref.watch(currentUserProvider),
        loadingMessage: l10n.authProfileLoading,
        onRetry: () => ref.read(currentUserProvider.notifier).refresh(),
        data: (user) => user == null
            ? LoadingView(message: l10n.authProfileLoading)
            : RefreshIndicator(
                onRefresh: () => ref.read(currentUserProvider.notifier).refresh(),
                child: ListView(
                  padding: const EdgeInsets.all(Gaps.md),
                  children: [
                    _Header(user: user),
                    const SizedBox(height: Gaps.md),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('edit-profile'),
                            onPressed: () => context.go('${AppRoutes.profile}/edit'),
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(l10n.authProfileEditEditProfile),
                          ),
                        ),
                        const SizedBox(width: Gaps.sm),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('security-settings'),
                            onPressed: () => context.go(AppRoutes.profileSecurity),
                            icon: const Icon(Icons.lock_outline),
                            label: Text(l10n.authProfileTabsSecurity),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gaps.lg),
                    _SectionTitle(l10n.authProfileDetailsHeading),
                    _Details(user: user),
                    const SizedBox(height: Gaps.lg),
                    _SectionTitle(l10n.authProfileSettingsHeading),
                    const _Settings(),
                    const SizedBox(height: Gaps.lg),
                    OutlinedButton.icon(
                      key: const Key('sign-out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.danger,
                        side: BorderSide(color: context.colors.danger.withValues(alpha: 0.5)),
                      ),
                      onPressed: () => _signOut(context, ref),
                      icon: const Icon(Icons.logout),
                      label: Text(l10n.commonActionsLogOut),
                    ),
                    const SizedBox(height: Gaps.lg),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.authProfileSignOutTitle,
      message: l10n.authProfileSignOutMessage,
      confirmLabel: l10n.commonActionsLogOut,
      destructive: true,
    );
    if (confirmed) {
      await ref.read(authServiceProvider).signOut();
    }
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final format = ref.watch(formattersProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gaps.md),
        child: Row(
          children: [
            UserAvatar(
              role: user.role,
              name: user.shownName,
              photoUrl: user.profilePhotoUrl,
              size: 72,
            ),
            const SizedBox(width: Gaps.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.shownName, style: textTheme.titleLarge),
                  Text(
                    '@${user.username}',
                    style: textTheme.bodyMedium!.mono.copyWith(color: context.colors.textSecondary),
                  ),
                  const SizedBox(height: Gaps.xs),
                  Wrap(
                    spacing: Gaps.sm,
                    runSpacing: Gaps.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusBadge(label: roleLabel(l10n, user.role.apiName)),
                      Text(
                        l10n.authProfileGeneralMemberSince(format.date(user.createdAt)),
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: Gaps.sm),
      child: Semantics(
        header: true,
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

/// The website's ProfileSummary: each detail, and where it can be changed.
class _Details extends ConsumerWidget {
  const _Details({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = ref.watch(formattersProvider);
    final securityNote = l10n.authProfileGeneralNoteSecuritySettings;
    final approvalNote = l10n.authProfileGeneralNoteRequiresApproval;
    final adminNote = l10n.authProfileGeneralNoteContactAdmin;
    // An admin changes their own full name and email directly; everyone else asks for approval.
    final nameEmailNote = user.role == Role.admin ? securityNote : approvalNote;
    final usernameAvailableAt = user.usernameChangeAvailableAt;

    final items = <_DetailItem>[
      _DetailItem(l10n.commonFieldsFullName, user.fullName, nameEmailNote),
      _DetailItem(
        l10n.authProfileGeneralDisplayName,
        user.displayName?.trim().isNotEmpty ?? false
            ? user.displayName
            : l10n.authProfileGeneralDisplayNameFallback,
      ),
      _DetailItem(
        l10n.commonFieldsUsername,
        '@${user.username}',
        usernameAvailableAt != null && !user.canChangeUsername()
            ? l10n.authProfileGeneralUsernameChangeOn(format.date(usernameAvailableAt))
            : l10n.authProfileGeneralUsernameChangeNow,
      ),
      _DetailItem(l10n.commonFieldsEmail, user.email, nameEmailNote),
      _DetailItem(l10n.commonFieldsRole, roleLabel(l10n, user.role.apiName), adminNote),
      _DetailItem(l10n.commonFieldsDistrict, user.district, adminNote),
      _DetailItem(l10n.commonFieldsPhoneNumber, user.phoneNumber, securityNote),
      if (user.role == Role.farmer) ...[
        _DetailItem(l10n.commonFieldsFieldPlotNumber, user.fieldPlotNumber),
        _DetailItem(l10n.commonFieldsNic, user.nic, approvalNote),
      ],
      if (user.role == Role.buyer) ...[
        _DetailItem(l10n.commonFieldsBusinessName, user.businessName),
        _DetailItem(
          l10n.commonFieldsBusinessRegistrationNumber,
          user.businessRegistrationNumber,
          adminNote,
        ),
        _DetailItem(l10n.commonFieldsNic, user.nic, approvalNote),
      ],
      if (user.role == Role.officer)
        _DetailItem(l10n.commonFieldsDepartment, user.departmentName, adminNote),
    ];

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(indent: Gaps.md, endIndent: Gaps.md),
            _DetailRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _DetailItem {
  const _DetailItem(this.label, this.value, [this.note]);

  final String label;
  final String? value;
  final String? note;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.item});

  final _DetailItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final value = item.value?.trim();
    final isSet = value != null && value.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gaps.md, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.label, style: textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            isSet ? value : l10n.authProfileGeneralNotSet,
            style: textTheme.bodyLarge?.copyWith(
              color: isSet ? colors.textPrimary : colors.textSecondary,
            ),
          ),
          if (item.note != null) ...[
            const SizedBox(height: 2),
            Text(
              item.note!,
              style: textTheme.bodySmall?.copyWith(
                color: colors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Settings extends ConsumerWidget {
  const _Settings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(themeModeProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gaps.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.commonLanguageLabel, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Gaps.sm),
            const LanguageSwitcher(),
            const SizedBox(height: Gaps.md),
            Text(l10n.commonThemeLabel, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Gaps.sm),
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                for (final option in [ThemeMode.light, ThemeMode.dark, ThemeMode.system])
                  ButtonSegment(
                    value: option,
                    icon: Icon(themeModeIcon(option)),
                    label: Text(
                      themeModeLabel(l10n, option),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              selected: {mode},
              onSelectionChanged: (selection) =>
                  ref.read(themeModeProvider.notifier).setMode(selection.first),
            ),
          ],
        ),
      ),
    );
  }
}
