import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/format/formatters.dart';
import '../../../core/session/role.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/labels.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/admin_providers.dart';
import '../application/user_filter.dart';
import '../data/admin_models.dart';
import 'widgets/user_card.dart';

/// Every account, with search (name, email, username) and filters by role and by whether the
/// account is active. The website shows this as a wide table; on a phone each user is a card.
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _search = TextEditingController();
  Role? _role;
  UserStatusFilter _status = UserStatusFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _role = null;
      _status = UserStatusFilter.all;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final users = ref.watch(adminUsersProvider);
    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.ordersAdminUsersTitle),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminUsersProvider);
          try {
            await ref.read(adminUsersProvider.future);
          } on Object {
            // The list shows the error itself; the spinner only has to stop.
          }
        },
        child: AsyncValueView<List<AdminUser>>(
          value: users,
          onRetry: () => ref.invalidate(adminUsersProvider),
          data: (all) => _List(
            all: all,
            shown: filterUsers(all, query: _search.text, role: _role, status: _status),
            filters: _Filters(
              search: _search,
              role: _role,
              status: _status,
              onSearchChanged: () => setState(() {}),
              onRole: (role) => setState(() => _role = role),
              onStatus: (status) => setState(() => _status = status),
            ),
            onClear: _clearFilters,
          ),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.search,
    required this.role,
    required this.status,
    required this.onSearchChanged,
    required this.onRole,
    required this.onStatus,
  });

  final TextEditingController search;
  final Role? role;
  final UserStatusFilter status;
  final VoidCallback onSearchChanged;
  final ValueChanged<Role?> onRole;
  final ValueChanged<UserStatusFilter> onStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.labelMedium?.copyWith(color: context.colors.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('user-search'),
          controller: search,
          onChanged: (_) => onSearchChanged(),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.adminUsersSearchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.marketplaceFiltersClear,
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      search.clear();
                      onSearchChanged();
                    },
                  ),
          ),
        ),
        const SizedBox(height: Gaps.sm),
        Text(l10n.commonFieldsRole, style: labelStyle),
        Wrap(
          spacing: Gaps.sm,
          children: [
            ChoiceChip(
              key: const Key('role-all'),
              label: Text(l10n.adminUsersFilterAll),
              selected: role == null,
              onSelected: (_) => onRole(null),
            ),
            for (final value in Role.values)
              ChoiceChip(
                key: Key('role-${value.apiName}'),
                label: Text(roleLabel(l10n, value.apiName)),
                selected: role == value,
                onSelected: (_) => onRole(value),
              ),
          ],
        ),
        const SizedBox(height: Gaps.xs),
        Text(l10n.commonFieldsStatus, style: labelStyle),
        Wrap(
          spacing: Gaps.sm,
          children: [
            for (final (value, label) in [
              (UserStatusFilter.all, l10n.adminUsersFilterAll),
              (UserStatusFilter.active, l10n.ordersAdminActive),
              (UserStatusFilter.inactive, l10n.ordersAdminInactive),
            ])
              ChoiceChip(
                key: Key('status-${value.name}'),
                label: Text(label),
                selected: status == value,
                onSelected: (_) => onStatus(value),
              ),
          ],
        ),
      ],
    );
  }
}

class _List extends ConsumerWidget {
  const _List({
    required this.all,
    required this.shown,
    required this.filters,
    required this.onClear,
  });

  final List<AdminUser> all;
  final List<AdminUser> shown;
  final Widget filters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final format = ref.watch(formattersProvider);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        filters,
        const SizedBox(height: Gaps.md),
        if (all.isEmpty)
          _Message(icon: Icons.group_outlined, text: l10n.ordersAdminNoUsers)
        else if (shown.isEmpty)
          _Message(
            icon: Icons.search_off_outlined,
            text: l10n.adminUsersNoMatches,
            action: TextButton(
              key: const Key('clear-filters'),
              onPressed: onClear,
              child: Text(l10n.marketplaceFiltersClear),
            ),
          )
        else ...[
          Text(
            l10n.adminUsersShowing(format.number(shown.length), format.number(all.length)),
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: Gaps.sm),
          for (final user in shown) ...[
            UserCard(key: ValueKey(user.userId), user: user),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gaps.lg),
      child: Column(
        children: [
          Icon(icon, size: 48, color: colors.textSecondary),
          const SizedBox(height: Gaps.md),
          Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          if (action != null) ...[const SizedBox(height: Gaps.sm), action!],
        ],
      ),
    );
  }
}
