import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../application/username_availability.dart';

/// The live verdict under a username field. Until there is one it shows the username rules;
/// the field's own error says which rule is broken. Read out when it changes.
class UsernameAvailabilityHint extends StatelessWidget {
  const UsernameAvailabilityHint({super.key, required this.status});

  final UsernameStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final (IconData? icon, String text, Color color) = switch (status) {
      UsernameStatus.checking => (null, l10n.commonUsernameChecking, colors.textSecondary),
      UsernameStatus.available => (
        Icons.check_circle,
        l10n.commonUsernameAvailable,
        colors.success,
      ),
      UsernameStatus.taken => (Icons.cancel, l10n.commonUsernameTaken, colors.danger),
      UsernameStatus.reserved => (Icons.cancel, l10n.commonUsernameReserved, colors.danger),
      UsernameStatus.error => (null, l10n.commonUsernameCheckFailed, colors.textSecondary),
      UsernameStatus.idle ||
      UsernameStatus.unchanged ||
      UsernameStatus.invalid => (null, l10n.commonUsernameHint, colors.textSecondary),
    };
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 4, right: 12),
        child: Row(
          children: [
            if (status == UsernameStatus.checking)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: SizedBox.square(
                  dimension: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              )
            else if (icon != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(icon, size: 16, color: color),
              ),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
