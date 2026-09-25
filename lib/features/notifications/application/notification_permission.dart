import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/permissions/permissions.dart';
import '../../../shared/widgets/dialogs.dart';

/// Asks once, after the user has signed in and reached their home, whether AgriLink may show
/// notification pop-ups (Android 13+ needs permission). First our own explanation, then
/// Android's prompt. Never on the very first screen, and never twice: after this it can be
/// turned on from the notifications screen.
Future<void> askForNotificationPermissionOnce(BuildContext context, WidgetRef ref) async {
  final preferences = ref.read(sharedPreferencesProvider);
  if (preferences.getBool(PrefKeys.notificationPermissionAsked) ?? false) {
    return;
  }
  final l10n = context.l10n;
  final permissions = ref.read(permissionServiceProvider);
  final status = await permissions.status(AppPermission.notifications);
  await preferences.setBool(PrefKeys.notificationPermissionAsked, true);
  // Already allowed (or Android before 13), or turned off for good: nothing to ask.
  if (status != PermissionResult.denied || !context.mounted) {
    return;
  }
  final proceed = await showConfirmDialog(
    context,
    title: l10n.commonPermissionsNotificationsTitle,
    message: l10n.commonPermissionsNotificationsRationale,
    confirmLabel: l10n.commonPermissionsContinue,
    cancelLabel: l10n.commonPermissionsNotNow,
  );
  if (proceed) {
    await permissions.request(AppPermission.notifications);
  }
}

/// Whether pop-ups are allowed, for the notifications screen's "Turn on" banner.
final notificationPermissionProvider = FutureProvider.autoDispose<PermissionResult>(
  (ref) => ref.watch(permissionServiceProvider).status(AppPermission.notifications),
);
