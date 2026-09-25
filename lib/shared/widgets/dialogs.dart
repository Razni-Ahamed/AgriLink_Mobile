import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../l10n/l10n.dart';

/// Asks the user to confirm an action. Returns true only if they confirm.
///
/// ```dart
/// if (await showConfirmDialog(context, title: l10n.x, message: l10n.y, destructive: true)) {
///   await api.delete(...);
/// }
/// ```
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel ?? l10n.commonActionsCancel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: context.colors.danger,
                  foregroundColor: context.colors.surface,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel ?? l10n.commonActionsConfirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

enum ToastTone { neutral, success, error }

/// A short message at the bottom of the screen, e.g. "Your profile has been updated."
void showToast(
  BuildContext context,
  String message, {
  ToastTone tone = ToastTone.neutral,
  SnackBarAction? action,
}) {
  final colors = context.colors;
  final icon = switch (tone) {
    ToastTone.success => Icons.check_circle_outline,
    ToastTone.error => Icons.error_outline,
    ToastTone.neutral => null,
  };
  final iconColor = switch (tone) {
    ToastTone.success => colors.success,
    ToastTone.error => colors.danger,
    ToastTone.neutral => null,
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        action: action,
        content: Row(
          children: [
            if (icon != null) ...[
              // Lightened so it reads on the dark snackbar in both themes.
              Icon(icon, color: Color.lerp(iconColor, Colors.white, 0.35)),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
