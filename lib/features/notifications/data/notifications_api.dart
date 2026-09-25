import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/api/paged.dart';

/// One notification. The title and message are written by the server, in English.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Json json) => AppNotification(
    id: (json['notificationId'] as num).toInt(),
    title: json['title'] as String? ?? '',
    message: json['message'] as String? ?? '',
    isRead: json['isRead'] == true,
    createdAt: parseApiDate(json['createdAt'] as String),
  );

  final int id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  AppNotification markedRead() =>
      AppNotification(id: id, title: title, message: message, isRead: true, createdAt: createdAt);
}

/// `/api/notifications`: the signed-in user's own notifications, newest first.
class NotificationsApi {
  NotificationsApi(this._api);

  final ApiClient _api;

  Future<Paged<AppNotification>> mine({int page = 1, int pageSize = 20}) => _api.getPaged(
    '/api/notifications/mine',
    page: page,
    pageSize: pageSize,
    item: AppNotification.fromJson,
  );

  Future<int> unreadCount() => _api.get(
    '/api/notifications/unread-count',
    decode: (data) => (asJson(data)['count'] as num).toInt(),
  );

  Future<AppNotification> markRead(int id) => _api.put(
    '/api/notifications/$id/read',
    decode: (data) => AppNotification.fromJson(asJson(data)),
  );

  Future<void> markAllRead() =>
      _api.put('/api/notifications/read-all', decode: ApiClient.ignoreBody);
}

final notificationsApiProvider = Provider<NotificationsApi>(
  (ref) => NotificationsApi(ref.watch(apiClientProvider)),
);
