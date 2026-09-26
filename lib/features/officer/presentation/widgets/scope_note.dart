import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/session/role.dart';
import '../../../../core/session/session_controller.dart';
import '../../../auth/application/current_user.dart';

/// A line above a queue saying what it covers: an officer's own district, and (when there is
/// wording for it) that an admin sees everywhere. An admin's [forAdmin] can be left out.
class ScopeNote extends ConsumerWidget {
  const ScopeNote({super.key, required this.forOfficer, this.forAdmin});

  final String Function(String district) forOfficer;
  final String? forAdmin;

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
