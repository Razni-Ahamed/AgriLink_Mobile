import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/session/session_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/locale_controller.dart';
import '../data/notifications_api.dart';
import 'notification_presenter.dart';

/// The number of unread notifications, for the bell's badge.
///
/// There are no push notifications yet, so while the user is signed in and the app is open this
/// asks the API every [AppConfig.unreadCountPollInterval], and straight away when the app comes
/// back to the foreground. When the count goes up, the user is told (see
/// [NotificationPresenter]). To add push later, call [refresh] from the push message handler;
/// the screens don't change.
final unreadCountProvider = NotifierProvider<UnreadCountController, int>(UnreadCountController.new);

class UnreadCountController extends Notifier<int> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  bool _hasBaseline = false;
  bool _refreshing = false;

  @override
  int build() {
    final token = ref.watch(sessionTokenProvider);
    ref.onDispose(_stop);
    _hasBaseline = false;
    if (token == null) {
      return 0;
    }
    _startTimer();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _startTimer();
        unawaited(refresh());
      },
      onHide: () => _timer?.cancel(),
    );
    Future.microtask(refresh);
    return 0;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(AppConfig.unreadCountPollInterval, (_) => refresh());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  /// Asks the API for the count now. Failures are ignored: the badge keeps its last value and
  /// the next poll tries again.
  Future<void> refresh() async {
    if (_refreshing || ref.read(sessionTokenProvider) == null) {
      return;
    }
    _refreshing = true;
    try {
      final count = await ref.read(notificationsApiProvider).unreadCount();
      if (!ref.mounted) {
        return;
      }
      final previous = state;
      state = count;
      // The first count after signing in is only the starting point, not news.
      if (_hasBaseline && count > previous) {
        await _announce(count - previous);
      }
      _hasBaseline = true;
    } on Object {
      // Keep the last count.
    } finally {
      _refreshing = false;
    }
  }

  /// After the user reads notifications, without waiting for the next poll.
  void setCount(int count) {
    state = count < 0 ? 0 : count;
  }

  Future<void> _announce(int newCount) async {
    final l10n = lookupAppLocalizations(ref.read(languageProvider).locale);
    var title = newCount == 1
        ? l10n.ordersNotificationsNewOne
        : l10n.ordersNotificationsNewMany(newCount);
    var body = '';
    if (newCount == 1) {
      // Show the notification itself when just one arrived.
      try {
        final latest = await ref.read(notificationsApiProvider).mine(pageSize: 1);
        if (latest.items.isNotEmpty) {
          title = latest.items.first.title;
          body = latest.items.first.message;
        }
      } on Object {
        // The generic wording above will do.
      }
    }
    if (ref.mounted) {
      await ref.read(notificationPresenterProvider).announce(title: title, body: body);
    }
  }
}
