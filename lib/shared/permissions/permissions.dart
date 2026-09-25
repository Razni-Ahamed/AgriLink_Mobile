import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/l10n.dart';
import '../widgets/dialogs.dart';

enum AppPermission { camera, notifications }

enum PermissionResult { granted, denied, permanentlyDenied }

/// The runtime permissions the app asks for, behind an interface so tests can fake them.
///
/// Only the camera and (Android 13+) notifications need asking. Choosing a photo from the
/// gallery uses Android's photo picker, which needs no permission at all.
abstract interface class PermissionService {
  Future<PermissionResult> status(AppPermission permission);
  Future<PermissionResult> request(AppPermission permission);
  Future<bool> openSettings();
}

class DevicePermissionService implements PermissionService {
  Permission _of(AppPermission permission) => switch (permission) {
    AppPermission.camera => Permission.camera,
    AppPermission.notifications => Permission.notification,
  };

  PermissionResult _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return PermissionResult.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return PermissionResult.permanentlyDenied;
    }
    return PermissionResult.denied;
  }

  @override
  Future<PermissionResult> status(AppPermission permission) async =>
      _map(await _of(permission).status);

  @override
  Future<PermissionResult> request(AppPermission permission) async =>
      _map(await _of(permission).request());

  @override
  Future<bool> openSettings() => openAppSettings();
}

final permissionServiceProvider = Provider<PermissionService>((ref) => DevicePermissionService());

/// Makes sure the camera may be used, asking only now that the user wants to take a photo:
/// first an explanation, then Android's own prompt. If it was turned off for good, offers to
/// open the app's settings. Returns whether the camera can be used.
Future<bool> ensureCameraPermission(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final permissions = ref.read(permissionServiceProvider);
  var result = await permissions.status(AppPermission.camera);
  if (result == PermissionResult.granted) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  if (result == PermissionResult.denied) {
    final proceed = await showConfirmDialog(
      context,
      title: l10n.commonPermissionsCameraTitle,
      message: l10n.commonPermissionsCameraRationale,
      confirmLabel: l10n.commonPermissionsContinue,
      cancelLabel: l10n.commonPermissionsNotNow,
    );
    if (!proceed) {
      return false;
    }
    result = await permissions.request(AppPermission.camera);
  }
  if (!context.mounted) {
    return false;
  }
  switch (result) {
    case PermissionResult.granted:
      return true;
    case PermissionResult.denied:
      showToast(context, l10n.commonPermissionsCameraDenied, tone: ToastTone.error);
      return false;
    case PermissionResult.permanentlyDenied:
      final open = await showConfirmDialog(
        context,
        title: l10n.commonPermissionsCameraTitle,
        message: l10n.commonPermissionsCameraBlocked,
        confirmLabel: l10n.commonActionsOpenSettings,
      );
      if (open) {
        await permissions.openSettings();
      }
      return false;
  }
}
