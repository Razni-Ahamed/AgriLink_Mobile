import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/dialogs.dart';
import '../data/messages_api.dart';
import '../messages_paths.dart';

/// What a chat is about: a purchase request (deal) or a crop issue (advice).
sealed class ChatSubject {
  const ChatSubject();
}

class DealChat extends ChatSubject {
  const DealChat(this.requestId);
  final int requestId;
}

class AdviceChat extends ChatSubject {
  const AdviceChat(this.issueId);
  final int issueId;
}

/// Opens the chat about [subject], creating it the first time, like the website's
/// StartChatButton. Used on requests, orders, issues and the officer's review screen.
class StartChatButton extends ConsumerStatefulWidget {
  const StartChatButton({super.key, required this.subject, required this.label});

  final ChatSubject subject;
  final String label;

  @override
  ConsumerState<StartChatButton> createState() => _StartChatButtonState();
}

class _StartChatButtonState extends ConsumerState<StartChatButton> {
  bool _opening = false;

  Future<void> _open() async {
    final l10n = context.l10n;
    setState(() => _opening = true);
    try {
      final api = ref.read(messagesApiProvider);
      final chat = await switch (widget.subject) {
        DealChat(:final requestId) => api.startDeal(requestId),
        AdviceChat(:final issueId) => api.startAdvice(issueId),
      };
      if (mounted) {
        await context.push(MessagesPaths.chat(chat.id));
      }
    } on Object {
      if (mounted) {
        showToast(context, l10n.messagesStartError, tone: ToastTone.error);
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: Key(
        'start-chat-${switch (widget.subject) {
          DealChat(:final requestId) => 'deal-$requestId',
          AdviceChat(:final issueId) => 'advice-$issueId',
        }}',
      ),
      onPressed: _opening ? null : _open,
      icon: _opening
          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.chat_bubble_outline, size: 18),
      label: Text(widget.label),
    );
  }
}
