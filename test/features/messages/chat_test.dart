import 'package:agrilink_mobile/app/router/app_routes.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';
import '../marketplace/marketplace_fixtures.dart';
import '../marketplace/marketplace_test_helpers.dart';

Map<String, Object?> summaryJson({int id = 5, int unread = 2, String? preview = 'Is it dry?'}) => {
  'conversationId': id,
  'kind': 'Deal',
  'title': 'Banana',
  'cropType': 'Banana',
  'quantity': 4,
  'unit': 'Bunch',
  'district': 'Kandy',
  'counterpartName': 'Nimal Silva',
  'counterpartRole': 'Buyer',
  'counterpartPhotoUrl': null,
  'lastMessagePreview': preview,
  'lastMessageIsMine': false,
  'lastMessageAt': '2026-11-08T09:00:00Z',
  'unreadCount': unread,
};

Map<String, Object?> detailJson({bool canSend = true, bool isClosed = false}) => {
  'conversationId': 5,
  'kind': 'Deal',
  'title': 'Banana',
  'cropType': 'Banana',
  'quantity': 4,
  'unit': 'Bunch',
  'district': 'Kandy',
  'counterpartName': 'Nimal Silva',
  'counterpartRole': 'Buyer',
  'counterpartBusinessName': 'Silva Traders',
  'counterpartPhotoUrl': null,
  'requestId': 21,
  'orderId': null,
  'harvestId': 9,
  'issueId': null,
  'advisoryId': null,
  'isClosed': isClosed,
  'canSend': canSend,
  'reportedByMe': false,
  'counterpartLastReadMessageId': null,
  'participants': null,
};

Map<String, Object?> messageJson(int id, String body, {bool mine = false}) => {
  'messageId': id,
  'senderUserId': mine ? 7 : 31,
  'senderName': mine ? 'Sunil Perera' : 'Nimal Silva',
  'senderRole': mine ? 'Farmer' : 'Buyer',
  'senderPhotoUrl': null,
  'body': body,
  'createdAt': '2026-11-08T09:00:00Z',
  'isMine': mine,
};

FakeApi chatApi({int unread = 2, bool canSend = true}) => marketplaceFakeApi(Role.farmer)
  ..on('GET', '/api/conversations/unread-count', (_) => FakeResponse(200, {'count': unread}))
  ..on(
    'GET',
    '/api/conversations',
    (_) => FakeResponse(200, {
      'items': [summaryJson(unread: unread)],
      'page': 1,
      'pageSize': 50,
      'totalCount': 1,
      'totalPages': 1,
    }),
  )
  ..on(
    'GET',
    '/api/conversations/5',
    (_) => FakeResponse(200, detailJson(canSend: canSend, isClosed: !canSend)),
  )
  ..on(
    'GET',
    '/api/conversations/5/messages',
    (_) => FakeResponse(200, {
      'items': [messageJson(1, 'Is it dry?')],
      'hasOlder': false,
    }),
  )
  ..on('PUT', '/api/conversations/5/read', (_) => const FakeResponse(204))
  ..on('GET', '/api/farms', (_) => const FakeResponse(200, []))
  ..on('GET', '/api/farmer/overview', (_) => const FakeResponse(404));

void main() {
  testWidgets('the chat button shows the unread count and opens the chats', (tester) async {
    await pumpMarketplace(tester, role: Role.farmer, api: chatApi(), path: '/messages');

    expect(find.byKey(const Key('chat-button')), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Nimal Silva'), findsOneWidget);
    expect(find.text('Banana · 4 bunches'), findsOneWidget);
    expect(find.text('Is it dry?'), findsOneWidget);
  });

  testWidgets('an admin gets no chat button', (tester) async {
    final api = marketplaceFakeApi(Role.admin)
      ..on('GET', '/api/admin/metrics', (_) => const FakeResponse(404));
    await pumpMarketplace(tester, role: Role.admin, api: api, path: AppRoutes.adminDashboard);

    expect(find.byKey(const Key('chat-button')), findsNothing);
  });

  testWidgets('opening a chat shows its messages, marks them read, and sends a reply', (
    tester,
  ) async {
    final api = chatApi()
      ..on(
        'POST',
        '/api/conversations/5/messages',
        (_) => FakeResponse(201, messageJson(2, 'Yes, sun-dried.', mine: true)),
      );
    await pumpMarketplace(tester, role: Role.farmer, api: api, path: '/messages/5');

    expect(find.text('Is it dry?'), findsOneWidget);
    expect(find.text('Banana · 4 bunches'), findsOneWidget);
    expect(api.lastTo('PUT', '/api/conversations/5/read'), isNotNull);

    await tester.enterText(find.byKey(const Key('chat-composer')), '  Yes, sun-dried. ');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();

    expect(api.lastTo('POST', '/api/conversations/5/messages')!.json, {'body': 'Yes, sun-dried.'});
    expect(find.text('Yes, sun-dried.'), findsOneWidget);
  });

  testWidgets('a closed chat can be read but has no box to write in', (tester) async {
    await pumpMarketplace(
      tester,
      role: Role.farmer,
      api: chatApi(canSend: false),
      path: '/messages/5',
    );

    expect(find.text('Is it dry?'), findsOneWidget);
    expect(find.byKey(const Key('chat-composer')), findsNothing);
    expect(
      find.text('This request was declined or withdrawn, so this chat is closed.'),
      findsOneWidget,
    );
  });

  testWidgets("a request card opens the request's chat", (tester) async {
    final api = chatApi()
      ..on('GET', '/api/purchase-requests/mine', (_) => FakeResponse(200, [requestJson()]))
      ..on('GET', '/api/orders/mine', (_) => const FakeResponse(200, []))
      ..on('POST', '/api/conversations/deal/21', (_) => FakeResponse(200, detailJson()));
    await pumpMarketplace(tester, role: Role.farmer, api: api, path: AppRoutes.incomingRequests);

    await tester.tapVisible(find.byKey(const Key('start-chat-deal-21')));
    await tester.pumpAndSettle();

    expect(api.lastTo('POST', '/api/conversations/deal/21'), isNotNull);
    expect(find.text('Is it dry?'), findsOneWidget);
  });
}
