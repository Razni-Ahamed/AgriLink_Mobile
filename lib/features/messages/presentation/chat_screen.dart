import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/format/formatters.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/state_views.dart';
import '../../farmer/farmer_paths.dart';
import '../../marketplace/marketplace_paths.dart';
import '../application/chat_providers.dart';
import '../data/messages_api.dart';
import 'chat_labels.dart';

/// One chat, like the website's ChatThread: the messages, newest at the bottom, and a box to
/// write in. It checks for new messages every [openChatPollInterval] while it is open and marks
/// the other side's messages read once they are on screen.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final int conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  Timer? _poll;
  ConversationDetail? _chat;
  List<ChatMessage> _messages = const [];
  bool _hasOlder = false;
  Object? _loadError;
  bool _loading = true;
  bool _sending = false;
  int _lastMarkedRead = 0;

  MessagesApi get _api => ref.read(messagesApiProvider);

  @override
  void initState() {
    super.initState();
    _composer.addListener(() => setState(() {}));
    unawaited(_load());
    _poll = Timer.periodic(openChatPollInterval, (_) => _refreshMessages());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final chat = await _api.conversation(widget.conversationId);
      final page = await _api.messages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _chat = chat;
        _messages = page.items;
        _hasOlder = page.hasOlder;
        _loading = false;
      });
      _afterNewMessages(jump: true);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _loadError = error;
          _loading = false;
        });
      }
    }
  }

  /// A failed poll is ignored; the next one tries again.
  Future<void> _refreshMessages() async {
    if (_chat == null || _sending) return;
    try {
      final page = await _api.messages(widget.conversationId);
      if (!mounted) return;
      final grew =
          page.items.isNotEmpty && (_messages.isEmpty || page.items.last.id != _messages.last.id);
      if (grew) {
        setState(() {
          _messages = page.items;
          _hasOlder = page.hasOlder;
        });
        _afterNewMessages();
      }
    } on Object {
      // Keep what is shown.
    }
  }

  void _afterNewMessages({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      jump
          ? _scroll.jumpTo(end)
          : unawaited(
              _scroll.animateTo(
                end,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              ),
            );
    });
    // Everything from the other side up to the newest message is now read.
    final lastFromOthers = _messages.lastWhere((m) => !m.isMine, orElse: () => _noMessage).id;
    if (lastFromOthers > _lastMarkedRead) {
      _lastMarkedRead = lastFromOthers;
      unawaited(
        _api
            .markRead(widget.conversationId)
            .then((_) => ref.read(chatUnreadCountProvider.notifier).refresh(), onError: (_) {}),
      );
    }
  }

  static final _noMessage = ChatMessage(
    id: 0,
    senderName: '',
    senderRole: '',
    body: '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    isMine: true,
  );

  Future<void> _send() async {
    final body = _composer.text.trim();
    if (body.isEmpty || _sending) return;
    final l10n = context.l10n;
    setState(() => _sending = true);
    try {
      final message = await _api.send(widget.conversationId, body);
      if (!mounted) return;
      _composer.clear();
      setState(() => _messages = [..._messages, message]);
      _afterNewMessages();
    } on Object catch (error) {
      if (mounted) {
        final tooFast = error is ApiException && error.statusCode == 429;
        showToast(
          context,
          tooFast
              ? l10n.messagesErrorsTooFast
              : (error is ApiException ? error.serverMessage : null) ??
                    l10n.messagesErrorsSendFailed,
          tone: ToastTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _report() async {
    final l10n = context.l10n;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReportDialog(),
    );
    if (reason == null || !mounted) return;
    try {
      await _api.report(widget.conversationId, reason);
      if (!mounted) return;
      showToast(context, l10n.messagesReportSent, tone: ToastTone.success);
      await _load();
    } on Object {
      if (mounted) showToast(context, l10n.messagesReportError, tone: ToastTone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chat = _chat;
    final format = ref.watch(formattersProvider);
    final title = chat == null
        ? l10n.messagesTitle
        : chatCounterpart(l10n, name: chat.counterpartName, district: chat.district);

    return Scaffold(
      appBar: AgriLinkAppBar(
        title: title,
        actions: [
          if (chat != null)
            IconButton(
              key: const Key('chat-report'),
              tooltip: chat.reportedByMe ? l10n.messagesReportAlready : l10n.messagesReportOpen,
              onPressed: chat.reportedByMe ? null : _report,
              icon: Icon(chat.reportedByMe ? Icons.flag : Icons.outlined_flag),
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : chat == null
          ? ErrorView(
              error: _loadError ?? l10n.messagesThreadNotFound,
              // Someone else's chat, or one that doesn't exist, says so plainly.
              message: switch (_loadError) {
                ApiException(kind: ApiErrorKind.notFound || ApiErrorKind.forbidden) =>
                  l10n.messagesThreadNotFound,
                _ => null,
              },
              onRetry: () {
                setState(() {
                  _loading = true;
                  _loadError = null;
                });
                unawaited(_load());
              },
            )
          : Column(
              children: [
                _SubjectBar(
                  chat: chat,
                  subject: chatSubject(
                    l10n,
                    format,
                    kind: chat.kind,
                    title: chat.title,
                    cropType: chat.cropType,
                    quantity: chat.quantity,
                    unit: chat.unit,
                  ),
                ),
                Expanded(
                  child: _MessageList(
                    controller: _scroll,
                    chat: chat,
                    messages: _messages,
                    hasOlder: _hasOlder,
                  ),
                ),
                if (chat.canSend)
                  _Composer(controller: _composer, sending: _sending, onSend: _send)
                else
                  _Notice(text: l10n.messagesThreadClosed),
              ],
            ),
    );
  }
}

/// What the chat is about, with a link to it: the request, order or advice.
class _SubjectBar extends StatelessWidget {
  const _SubjectBar({required this.chat, required this.subject});

  final ConversationDetail chat;
  final String subject;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final (label, path) = switch (chat) {
      ConversationDetail(orderId: final int id) => (
        l10n.messagesThreadViewOrder,
        MarketplacePaths.order(id),
      ),
      ConversationDetail(advisoryId: final int id) => (
        l10n.messagesThreadViewAdvice,
        FarmerPaths.advisory(id),
      ),
      ConversationDetail(harvestId: final int id) => (
        l10n.messagesThreadViewRequest,
        MarketplacePaths.listing(id),
      ),
      _ => (null, null),
    };
    return Material(
      color: colors.forest.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.sm, Gaps.sm, Gaps.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.kind == ConversationKind.deal
                        ? l10n.messagesKindDeal
                        : l10n.messagesKindAdvice,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.textSecondary),
                  ),
                  Text(
                    subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
            if (label != null && path != null)
              TextButton(onPressed: () => context.push(path), child: Text(label)),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends ConsumerWidget {
  const _MessageList({
    required this.controller,
    required this.chat,
    required this.messages,
    required this.hasOlder,
  });

  final ScrollController controller;
  final ConversationDetail chat;
  final List<ChatMessage> messages;
  final bool hasOlder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final format = ref.watch(formattersProvider);
    final text = Theme.of(context).textTheme;
    final lastMine = messages.lastWhere(
      (m) => m.isMine,
      orElse: () => messages.isEmpty ? _empty : messages.first,
    );
    final seen = lastMine.isMine && (chat.counterpartLastReadMessageId ?? 0) >= lastMine.id;

    return ListView(
      key: const Key('chat-messages'),
      controller: controller,
      padding: const EdgeInsets.all(Gaps.md),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Gaps.md),
          child: Text(
            l10n.messagesThreadSafety,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: colors.textSecondary),
          ),
        ),
        if (hasOlder)
          Padding(
            padding: const EdgeInsets.only(bottom: Gaps.sm),
            child: Text(
              l10n.messagesThreadOlderHidden,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ),
        if (messages.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Gaps.xl),
            child: Text(
              l10n.messagesThreadNoMessages,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ),
        for (final message in messages) ...[
          Align(
            alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
              child: Container(
                key: Key('message-${message.id}'),
                margin: const EdgeInsets.only(bottom: Gaps.sm),
                padding: const EdgeInsets.symmetric(horizontal: Gaps.sm + 4, vertical: Gaps.sm),
                decoration: BoxDecoration(
                  color: message.isMine ? colors.forest : colors.surface,
                  border: message.isMine ? null : Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // An advice chat can have several officers, so say who wrote it.
                    if (!message.isMine && chat.kind == ConversationKind.advice)
                      Text(
                        '${message.senderName} · ${chatRole(l10n, message.senderRole)}',
                        style: text.labelSmall?.copyWith(color: colors.forest),
                      ),
                    Text(
                      message.body,
                      style: text.bodyMedium?.copyWith(
                        color: message.isMine ? colors.surface : colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      format.dateTime(message.createdAt),
                      style: text.labelSmall?.copyWith(
                        color: message.isMine
                            ? colors.surface.withValues(alpha: 0.8)
                            : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (seen)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              l10n.messagesThreadSeen,
              style: text.labelSmall?.copyWith(color: colors.textSecondary),
            ),
          ),
      ],
    );
  }

  static final _empty = ChatMessage(
    id: 0,
    senderName: '',
    senderRole: '',
    body: '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    isMine: false,
  );
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.onSend});

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canSend = controller.text.trim().isNotEmpty && !sending;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.sm, Gaps.sm, Gaps.sm),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.colors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('chat-composer'),
                controller: controller,
                minLines: 1,
                maxLines: 5,
                maxLength: maxChatMessageLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.messagesComposerPlaceholder,
                  counterText: '',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: Gaps.sm),
            IconButton.filled(
              key: const Key('chat-send'),
              tooltip: l10n.messagesComposerSend,
              onPressed: canSend ? onSend : null,
              icon: sending
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Gaps.md),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.colors.border)),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 18, color: context.colors.textSecondary),
            const SizedBox(width: Gaps.sm),
            Expanded(
              child: Text(text, style: TextStyle(color: context.colors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks what is wrong; returns the reason, or null if cancelled.
class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.messagesReportTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.messagesReportIntro),
          const SizedBox(height: Gaps.md),
          TextField(
            key: const Key('chat-report-reason'),
            controller: _reason,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(labelText: l10n.messagesReportReason),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.messagesReportCancel),
        ),
        FilledButton(
          onPressed: _reason.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_reason.text.trim()),
          child: Text(l10n.messagesReportSubmit),
        ),
      ],
    );
  }
}
