import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/session_controller.dart';
import '../../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'agrilink_app_bar.dart';
import 'nav_config.dart';

/// The sections that don't fit on the bottom bar, then the profile and notifications.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final role = ref.watch(sessionControllerProvider).role;
    final overflow = role == null ? const <NavDestination>[] : navigationFor(role).overflow;
    final entries = [...overflow, Destinations.notifications, Destinations.profile];
    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.commonNavMore),
      body: ListView.separated(
        padding: const EdgeInsets.all(Gaps.md),
        itemCount: entries.length,
        separatorBuilder: (_, index) => SizedBox(
          // A wider gap between the role's sections and the account entries.
          height: index == overflow.length - 1 ? Gaps.lg : Gaps.sm,
        ),
        itemBuilder: (context, index) {
          final destination = entries[index];
          return Card(
            child: ListTile(
              leading: Icon(destination.icon),
              title: Text(destination.label(l10n)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(destination.path),
            ),
          );
        },
      ),
    );
  }
}
