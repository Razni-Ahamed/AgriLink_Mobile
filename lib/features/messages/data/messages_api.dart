import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/api/paged.dart';
import '../../marketplace/data/marketplace_enums.dart';

/// A deal chat is about one purchase request; an advice chat about one crop issue.
enum ConversationKind {
  deal('Deal'),
  advice('Advice');

  const ConversationKind(this.apiName);

  factory ConversationKind.fromApi(Object? raw) =>
      values.firstWhere((value) => value.apiName == raw, orElse: () => ConversationKind.advice);

  final String apiName;
}

/// One row of the chat list: the API's `ConversationSummary`.
class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.kind,
    required this.title,
    required this.cropType,
    required this.district,
    required this.counterpartRole,
    required this.lastMessageIsMine,
    required this.unreadCount,
    this.quantity,
    this.unit = QuantityUnit.kg,
    this.counterpartName,
    this.counterpartPhotoUrl,
    this.lastMessagePreview,
    this.lastMessageAt,
  });

  factory ConversationSummary.fromJson(Json json) => ConversationSummary(
    id: (json['conversationId'] as num).toInt(),
    kind: ConversationKind.fromApi(json['kind']),
    title: json['title'] as String? ?? '',
    cropType: json['cropType'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toDouble(),
    unit: QuantityUnit.fromApi(json['unit']),
    district: json['district'] as String? ?? '',
    counterpartName: json['counterpartName'] as String?,
    counterpartRole: json['counterpartRole'] as String? ?? '',
    counterpartPhotoUrl: json['counterpartPhotoUrl'] as String?,
    lastMessagePreview: json['lastMessagePreview'] as String?,
    lastMessageIsMine: json['lastMessageIsMine'] == true,
    lastMessageAt: parseApiDateOrNull(json['lastMessageAt']),
    unreadCount: (json['unreadCount'] as num? ?? 0).toInt(),
  );

  final int id;
  final ConversationKind kind;

  /// Deal: the crop. Advice: the issue's title.
  final String title;
  final String cropType;
  final double? quantity;
  final QuantityUnit unit;
  final String district;

  /// Null for a farmer's advice chat, which is with the district's officers as a group.
  final String? counterpartName;

  /// "Farmer", "Buyer" or "Officer".
  final String counterpartRole;
  final String? counterpartPhotoUrl;
  final String? lastMessagePreview;
  final bool lastMessageIsMine;
  final DateTime? lastMessageAt;
  final int unreadCount;
}

/// One chat, opened: the API's `ConversationDetail`.
class ConversationDetail {
  const ConversationDetail({
    required this.id,
    required this.kind,
    required this.title,
    required this.cropType,
    required this.district,
    required this.counterpartRole,
    required this.isClosed,
    required this.canSend,
    required this.reportedByMe,
    this.quantity,
    this.unit = QuantityUnit.kg,
    this.counterpartName,
    this.counterpartBusinessName,
    this.requestId,
    this.orderId,
    this.harvestId,
    this.issueId,
    this.advisoryId,
    this.counterpartLastReadMessageId,
  });

  factory ConversationDetail.fromJson(Json json) => ConversationDetail(
    id: (json['conversationId'] as num).toInt(),
    kind: ConversationKind.fromApi(json['kind']),
    title: json['title'] as String? ?? '',
    cropType: json['cropType'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toDouble(),
    unit: QuantityUnit.fromApi(json['unit']),
    district: json['district'] as String? ?? '',
    counterpartName: json['counterpartName'] as String?,
    counterpartRole: json['counterpartRole'] as String? ?? '',
    counterpartBusinessName: json['counterpartBusinessName'] as String?,
    requestId: (json['requestId'] as num?)?.toInt(),
    orderId: (json['orderId'] as num?)?.toInt(),
    harvestId: (json['harvestId'] as num?)?.toInt(),
    issueId: (json['issueId'] as num?)?.toInt(),
    advisoryId: (json['advisoryId'] as num?)?.toInt(),
    isClosed: json['isClosed'] == true,
    canSend: json['canSend'] == true,
    reportedByMe: json['reportedByMe'] == true,
    counterpartLastReadMessageId: (json['counterpartLastReadMessageId'] as num?)?.toInt(),
  );

  final int id;
  final ConversationKind kind;
  final String title;
  final String cropType;
  final double? quantity;
  final QuantityUnit unit;
  final String district;
  final String? counterpartName;
  final String counterpartRole;
  final String? counterpartBusinessName;
  final int? requestId;
  final int? orderId;
  final int? harvestId;
  final int? issueId;
  final int? advisoryId;

  /// A declined or withdrawn request with no order: readable, but no new messages.
  final bool isClosed;
  final bool canSend;
  final bool reportedByMe;

  /// For "Seen" under the caller's own messages.
  final int? counterpartLastReadMessageId;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderName,
    required this.senderRole,
    required this.body,
    required this.createdAt,
    required this.isMine,
  });

  factory ChatMessage.fromJson(Json json) => ChatMessage(
    id: (json['messageId'] as num).toInt(),
    senderName: json['senderName'] as String? ?? '',
    senderRole: json['senderRole'] as String? ?? '',
    body: json['body'] as String? ?? '',
    createdAt: parseApiDate(field<String>(json, 'createdAt')),
    isMine: json['isMine'] == true,
  );

  final int id;
  final String senderName;
  final String senderRole;
  final String body;
  final DateTime createdAt;
  final bool isMine;
}

/// The newest messages, oldest first.
class ChatMessagePage {
  const ChatMessagePage({required this.items, required this.hasOlder});

  factory ChatMessagePage.fromJson(Json json) => ChatMessagePage(
    items: [
      for (final item in (json['items'] as List<Object?>? ?? const []))
        ChatMessage.fromJson(asJson(item)),
    ],
    hasOlder: json['hasOlder'] == true,
  );

  final List<ChatMessage> items;
  final bool hasOlder;
}

/// The longest message the API accepts.
const int maxChatMessageLength = 1000;

/// `/api/conversations`: chats between farmers, buyers and officers, as on the website.
class MessagesApi {
  MessagesApi(this._api);

  final ApiClient _api;

  Future<Paged<ConversationSummary>> conversations({int page = 1, int pageSize = 50}) =>
      _api.getPaged(
        '/api/conversations',
        page: page,
        pageSize: pageSize,
        item: ConversationSummary.fromJson,
      );

  Future<int> unreadCount() => _api.get(
    '/api/conversations/unread-count',
    decode: (data) => (asJson(data)['count'] as num).toInt(),
  );

  /// Opens the chat about a purchase request, creating it the first time.
  Future<ConversationDetail> startDeal(int requestId) =>
      _api.post('/api/conversations/deal/$requestId', decode: _detail);

  /// Opens the chat about a crop issue, creating it the first time.
  Future<ConversationDetail> startAdvice(int issueId) =>
      _api.post('/api/conversations/advice/$issueId', decode: _detail);

  Future<ConversationDetail> conversation(int id) =>
      _api.get('/api/conversations/$id', decode: _detail);

  Future<ChatMessagePage> messages(int id) => _api.get(
    '/api/conversations/$id/messages',
    decode: (data) => ChatMessagePage.fromJson(asJson(data)),
  );

  Future<ChatMessage> send(int id, String body) => _api.post(
    '/api/conversations/$id/messages',
    body: {'body': body},
    decode: (data) => ChatMessage.fromJson(asJson(data)),
  );

  Future<void> markRead(int id) =>
      _api.put('/api/conversations/$id/read', decode: ApiClient.ignoreBody);

  Future<void> report(int id, String reason) => _api.post(
    '/api/conversations/$id/report',
    body: {'reason': reason},
    decode: ApiClient.ignoreBody,
  );

  static ConversationDetail _detail(Object? data) => ConversationDetail.fromJson(asJson(data));
}

final messagesApiProvider = Provider<MessagesApi>(
  (ref) => MessagesApi(ref.watch(apiClientProvider)),
);
