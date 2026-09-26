import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/labels.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../data/admin_models.dart';

/// The badge saying whether an account can sign in. Written out and given an icon, so it doesn't
/// rely on colour.
class ActiveBadge extends StatelessWidget {
  const ActiveBadge({super.key, required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StatusBadge(
      label: isActive ? l10n.ordersAdminActive : l10n.ordersAdminInactive,
      tone: isActive ? BadgeTone.success : BadgeTone.neutral,
      icon: isActive ? Icons.check_circle_outline : Icons.pause_circle_outline,
    );
  }
}

/// "Kandy · Agriculture" for an officer, "Kandy" for anyone else with a district, or nothing.
String? userPlace(AdminUser user) {
  final parts = [
    if (user.district != null && user.district!.isNotEmpty) user.district!,
    if (user.department != null && user.department!.isNotEmpty) user.department!,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// One user in the list: avatar, name, email and username, their role and where they are, and
/// whether they're active.
class UserCard extends StatelessWidget {
  const UserCard({super.key, required this.user, this.onTap});

  final AdminUser user;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final place = userPlace(user);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gaps.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(
                role: user.role,
                name: user.fullName,
                photoUrl: user.profilePhotoUrl,
                size: 44,
              ),
              const SizedBox(width: Gaps.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName, style: textTheme.titleMedium),
                    Text(
                      user.email,
                      style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                    ),
                    Text(
                      '@${user.username}',
                      style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                    ),
                    const SizedBox(height: Gaps.sm),
                    Wrap(
                      spacing: Gaps.sm,
                      runSpacing: Gaps.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusBadge(
                          label: roleLabel(l10n, user.role.apiName),
                          tone: BadgeTone.info,
                        ),
                        ActiveBadge(isActive: user.isActive),
                      ],
                    ),
                    if (place != null) ...[
                      const SizedBox(height: Gaps.xs),
                      Text(
                        place,
                        style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
