import 'package:go_router/go_router.dart';

import '../../app/router/route_guard.dart';
import '../../core/session/role.dart';
import 'messages_paths.dart';
import 'presentation/chat_screen.dart';
import 'presentation/messages_screen.dart';

/// Chat for farmers, buyers and officers, opened from the app bar's chat button. An admin
/// reads reported chats on the website.
const _chatRoles = {Role.farmer, Role.buyer, Role.officer};

List<RouteBase> messagesRoutes(RouteGuard guard) => [
  guard.route(
    path: MessagesPaths.list,
    roles: _chatRoles,
    builder: (context, state) => const MessagesScreen(),
  ),
  guard.route(
    path: MessagesPaths.chatPattern,
    roles: _chatRoles,
    builder: (context, state) =>
        // A malformed id asks for chat 0, which the API answers with "not found".
        ChatScreen(conversationId: int.tryParse(state.pathParameters['conversationId']!) ?? 0),
  ),
];
