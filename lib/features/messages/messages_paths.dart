/// Addresses inside the chat section, matching the website's.
abstract final class MessagesPaths {
  static const list = '/messages';
  static const chatPattern = '/messages/:conversationId';

  static String chat(int conversationId) => '/messages/$conversationId';
}
