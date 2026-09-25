import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../l10n/locale_controller.dart';
import '../../../shared/permissions/permissions.dart';

/// The app's [ScaffoldMessenger], for messages that don't come from a particular screen.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Tells the user that something new arrived. It only decides *how* to tell them, not *when*:
/// the unread-count poller calls it today, and a push message handler can call it later.
abstract interface class NotificationPresenter {
  /// Called when the user taps the pop-up or the "View" button. Set once by the app.
  set onOpen(VoidCallback? callback);

  Future<void> announce({required String title, required String body});
}

/// A system pop-up through flutter_local_notifications when notifications are allowed, or an
/// in-app message with a "View" button when they aren't.
class DeviceNotificationPresenter implements NotificationPresenter {
  DeviceNotificationPresenter(this._ref);

  final Ref _ref;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _nextId = 0;
  VoidCallback? _onOpen;

  static const _channelId = 'agrilink_updates';

  @override
  set onOpen(VoidCallback? callback) => _onOpen = callback;

  AppLocalizations get _l10n => lookupAppLocalizations(_ref.read(languageProvider).locale);

  Future<void> _initialize() async {
    if (_initialized) {
      return;
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (_) => _onOpen?.call(),
    );
    _initialized = true;
  }

  @override
  Future<void> announce({required String title, required String body}) async {
    final allowed =
        await _ref.read(permissionServiceProvider).status(AppPermission.notifications) ==
        PermissionResult.granted;
    if (allowed) {
      await _initialize();
      final l10n = _l10n;
      await _plugin.show(
        id: _nextId++,
        title: title,
        body: body.isEmpty ? null : body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            l10n.ordersNotificationsChannelName,
            channelDescription: l10n.ordersNotificationsChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
      return;
    }
    rootMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(body.isEmpty ? title : '$title\n$body'),
        action: SnackBarAction(
          label: _l10n.ordersNotificationsView,
          onPressed: () => _onOpen?.call(),
        ),
      ),
    );
  }
}

final notificationPresenterProvider = Provider<NotificationPresenter>(
  DeviceNotificationPresenter.new,
);
