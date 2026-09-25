import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/session/role.dart';
import '../../../core/session/session_controller.dart';
import '../../../features/auth/application/current_user.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/paged_list.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/pending_registrations.dart';
import '../data/approvals_api.dart';
import 'widgets/change_request_card.dart';
import 'widgets/registration_card.dart';

/// Everything an officer or admin has to approve, in two tabs like the website: new
/// registrations, and changes to a user's name, NIC or email. The server scopes what each role
/// receives, so this screen is the same for both.
class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AgriLinkAppBar(
          title: l10n.registrationsPendingPageTitle,
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.registrationsPendingTabsRegistrations),
              Tab(text: l10n.registrationsPendingTabsProfileChanges),
            ],
          ),
        ),
        body: const TabBarView(children: [_RegistrationsTab(), _ProfileChangesTab()]),
      ),
    );
  }
}

/// A line above a queue saying what it covers: an officer's own district, or (for an admin)
/// everywhere, which is also how an admin learns that Buyer applications arrive here.
class _ScopeNote extends ConsumerWidget {
  const _ScopeNote({required this.forOfficer, required this.forAdmin});

  final String Function(String district) forOfficer;
  final String forAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(sessionControllerProvider).role;
    final district = ref.watch(currentUserProvider).value?.district;
    final text = switch (role) {
      Role.officer when district != null && district.isNotEmpty => forOfficer(district),
      Role.admin => forAdmin,
      _ => null,
    };
    if (text == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.sm, Gaps.md, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.place_outlined, size: 16, color: context.colors.textSecondary),
          const SizedBox(width: Gaps.xs),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: context.colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationsTab extends ConsumerWidget {
  const _RegistrationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final applications = ref.watch(pendingRegistrationsProvider);
    return Column(
      children: [
        _ScopeNote(
          forOfficer: l10n.registrationsPendingScopedToDistrict,
          forAdmin: l10n.registrationsPendingScopedToAll,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(pendingRegistrationsProvider);
              try {
                await ref.read(pendingRegistrationsProvider.future);
              } on Object {
                // The tab shows the error itself.
              }
            },
            child: AsyncValueView<List<PendingRegistration>>(
              value: applications,
              onRetry: () => ref.invalidate(pendingRegistrationsProvider),
              data: (items) => items.isEmpty
                  ? EmptyView(
                      icon: Icons.how_to_reg_outlined,
                      title: l10n.registrationsPendingEmpty,
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => RegistrationCard(
                        key: ValueKey(items[index].userId),
                        application: items[index],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileChangesTab extends ConsumerStatefulWidget {
  const _ProfileChangesTab();

  @override
  ConsumerState<_ProfileChangesTab> createState() => _ProfileChangesTabState();
}

class _ProfileChangesTabState extends ConsumerState<_ProfileChangesTab> {
  late final PagedListController<PendingChangeRequest> _requests = PagedListController(
    loadPage: (page) => ref.read(approvalsApiProvider).pendingChangeRequests(page: page),
  );

  @override
  void dispose() {
    _requests.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        _ScopeNote(
          forOfficer: l10n.registrationsPendingChangesScopedToDistrict,
          forAdmin: l10n.registrationsPendingChangesScopedToAll,
        ),
        Expanded(
          child: PagedListView<PendingChangeRequest>(
            controller: _requests,
            empty: EmptyView(
              icon: Icons.manage_accounts_outlined,
              title: l10n.registrationsPendingChangesEmpty,
            ),
            itemBuilder: (context, request, _) => ChangeRequestCard(
              key: ValueKey(request.requestId),
              request: request,
              onDecided: _requests.refresh,
            ),
          ),
        ),
      ],
    );
  }
}
