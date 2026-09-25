import 'package:agrilink_mobile/features/notifications/application/notification_presenter.dart';
import 'package:agrilink_mobile/shared/permissions/permissions.dart';
import 'package:flutter/foundation.dart';

/// Permissions that answer [result] to everything, and count what was asked.
class FakePermissions implements PermissionService {
  FakePermissions([this.result = PermissionResult.granted]);

  PermissionResult result;
  final List<AppPermission> requested = [];
  int settingsOpened = 0;

  @override
  Future<PermissionResult> status(AppPermission permission) async => result;

  @override
  Future<PermissionResult> request(AppPermission permission) async {
    requested.add(permission);
    return result;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

/// Records what would have been shown as a pop-up.
class FakePresenter implements NotificationPresenter {
  final List<({String title, String body})> announced = [];
  VoidCallback? openCallback;

  @override
  set onOpen(VoidCallback? callback) => openCallback = callback;

  @override
  Future<void> announce({required String title, required String body}) async {
    announced.add((title: title, body: body));
  }
}
