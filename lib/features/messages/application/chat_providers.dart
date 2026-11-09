import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/role.dart';
import '../../../core/session/session_controller.dart';
import '../data/messages_api.dart';

/// How often the chat badge and an open chat check for new messages, as on the website. The
/// free App Service plan allows only a few live connections, so chat polls rather than pushing.
const Duration chatUnreadPollInterval = Duration(seconds: 30);
const Duration openChatPollInterval = Duration(seconds: 10);

/// Chat is for farmers, buyers and officers; an admin reads a chat only once it is reported,
/// and does that on the website.
bool canChat(Role? role) => role == Role.farmer || role == Role.buyer || role == Role.officer;

/// The signed-in user's chats, newest activity first.
final conversationsProvider = FutureProvider.autoDispose<List<ConversationSummary>>((ref) async {
  // Thrown away on sign-out, so the next person on this phone never sees these chats.
  ref.watch(sessionTokenProvider);
  final page = await ref.watch(messagesApiProvider).conversations();
  return page.items;
});

/// Unread chat messages, for the badge on the app bar's chat button. Polls while the app is
/// open and the user can chat; pauses in the background.
final chatUnreadCountProvider = NotifierProvider<ChatUnreadCountController, int>(
  ChatUnreadCountController.new,
);

class ChatUnreadCountController extends Notifier<int> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  @override
  int build() {
    final token = ref.watch(sessionTokenProvider);
    final role = ref.watch(sessionControllerProvider.select((session) => session.role));
    ref.onDispose(_stop);
    if (token == null || !canChat(role)) {
      return 0;
    }
    _timer = Timer.periodic(chatUnreadPollInterval, (_) => refresh());
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _timer?.cancel();
        _timer = Timer.periodic(chatUnreadPollInterval, (_) => refresh());
        unawaited(refresh());
      },
      onHide: () => _timer?.cancel(),
    );
    Future.microtask(refresh);
    return 0;
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  /// Asks the API now. A failure keeps the last count; the next poll tries again.
  Future<void> refresh() async {
    if (ref.read(sessionTokenProvider) == null) {
      return;
    }
    try {
      final count = await ref.read(messagesApiProvider).unreadCount();
      if (ref.mounted) {
        state = count;
      }
    } on Object {
      // Keep the badge as it was.
    }
  }
}
