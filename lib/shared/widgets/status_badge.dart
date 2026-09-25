import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../l10n/l10n.dart';
import '../../l10n/labels.dart';

/// The badge colours, as on the website's Badge component.
enum BadgeTone { success, warning, danger, info, neutral }

/// A sensible tone for a status value from the API. Screens may pick their own.
BadgeTone toneForStatus(String value) => switch (value) {
  'Approved' ||
  'Resolved' ||
  'Completed' ||
  'Accepted' ||
  'Active' ||
  'Harvested' ||
  'Low' => BadgeTone.success,
  'Pending' ||
  'AwaitingReview' ||
  'Draft' ||
  'Preliminary' ||
  'Medium' ||
  'Growing' ||
  'Seeded' => BadgeTone.warning,
  'Rejected' || 'Declined' || 'Cancelled' || 'High' => BadgeTone.danger,
  'Confirmed' || 'Sold' => BadgeTone.info,
  _ => BadgeTone.neutral,
};

/// A small rounded label such as "Pending" or "Approved".
///
/// ```dart
/// StatusBadge.status(StatusKind.issue, issue.status)   // translated, toned automatically
/// StatusBadge(label: 'New', tone: BadgeTone.info)
/// ```
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
  });

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  /// A translated API status with its usual tone.
  static Widget status(StatusKind kind, String value, {Key? key}) => Builder(
    key: key,
    builder: (context) => StatusBadge(
      label: statusLabel(context.l10n, kind, value),
      tone: toneForStatus(value),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = switch (tone) {
      BadgeTone.success => colors.success,
      BadgeTone.warning => colors.harvest,
      BadgeTone.danger => colors.danger,
      BadgeTone.info => colors.info,
      BadgeTone.neutral => colors.textSecondary,
    };
    // Gold text on a gold wash is too faint in light mode; use the ink colour for warnings.
    final textColor = tone == BadgeTone.warning ? colors.textPrimary : color;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.tint(color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: textColor, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
