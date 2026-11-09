import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/format/formatters.dart';
import '../../../core/session/role.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../application/chat_providers.dart';
import '../data/messages_api.dart';
import '../messages_paths.dart';
import 'chat_labels.dart';

/// The signed-in user's chats, like the website's /messages list. Tapping one opens it.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.messagesTitle),
      body: switch (ref.watch(conversationsProvider)) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () async {
            await ref.read(chatUnreadCountProvider.notifier).refresh();
            return ref.refresh(conversationsProvider.future);
          },
          child: value.isEmpty
              ? ListView(
                  // Scrollable, so pull-to-refresh works on an empty list too.
                  children: [
                    SizedBox(
                      height: 420,
                      child: EmptyView(
                        icon: Icons.forum_outlined,
                        title: l10n.messagesListEmpty,
                        message: l10n.messagesListEmptyHint,
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  key: const Key('conversations'),
                  padding: const EdgeInsets.symmetric(vertical: Gaps.sm),
                  itemCount: value.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => _ConversationTile(chat: value[index]),
                ),
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(conversationsProvider),
        ),
        _ => const LoadingView(),
      },
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.chat});

  final ConversationSummary chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = ref.watch(formattersProvider);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final unread = chat.unreadCount > 0;
    final name = chatCounterpart(l10n, name: chat.counterpartName, district: chat.district);
    final preview = chat.lastMessagePreview;

    return ListTile(
      key: Key('conversation-${chat.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: Gaps.md, vertical: Gaps.xs),
      leading: UserAvatar(
        role: Role.fromApi(chat.counterpartRole) ?? Role.officer,
        name: name,
        photoUrl: chat.counterpartPhotoUrl,
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: unread ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chatSubject(
              l10n,
              format,
              kind: chat.kind,
              title: chat.title,
              cropType: chat.cropType,
              quantity: chat.quantity,
              unit: chat.unit,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: colors.forest),
          ),
          if (preview != null)
            Text(
              chat.lastMessageIsMine ? l10n.messagesListYou(preview) : preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: unread
                  ? TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)
                  : null,
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (chat.lastMessageAt != null)
            Text(
              format.date(chat.lastMessageAt!),
              style: text.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          if (unread)
            Padding(
              padding: const EdgeInsets.only(top: Gaps.xs),
              child: Badge(
                label: Text(chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}'),
                backgroundColor: colors.forest,
              ),
            ),
        ],
      ),
      onTap: () => context.push(MessagesPaths.chat(chat.id)),
    );
  }
}
