import 'package:agrilink_mobile/core/api/api_client.dart';
import 'package:agrilink_mobile/core/api/api_exception.dart';
import 'package:agrilink_mobile/core/api/json.dart';
import 'package:agrilink_mobile/core/api/paged.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';

void main() {
  group('Paged', () {
    test('reads the page envelope and maps items', () {
      final paged = Paged.fromJson({
        'items': [
          {'id': 1},
          {'id': 2},
        ],
        'page': 1,
        'pageSize': 2,
        'totalCount': 5,
        'totalPages': 3,
      }, (json) => json['id'] as int);
      expect(paged.items, [1, 2]);
      expect(paged.hasMore, isTrue);
      expect(paged.map((id) => 'n$id').items, ['n1', 'n2']);
    });

    test('knows the last page and an empty list', () {
      final last = Paged.fromJson({
        'items': <Object>[],
        'page': 3,
        'pageSize': 2,
        'totalCount': 0,
        'totalPages': 3,
      }, (json) => json);
      expect(last.hasMore, isFalse);
      expect(const Paged<int>.empty().isEmpty, isTrue);
    });
  });

  test('API dates without an offset are read as UTC', () {
    expect(parseApiDate('2026-09-25T10:00:00').isUtc, isTrue);
    expect(parseApiDate('2026-09-25T10:00:00'), DateTime.utc(2026, 9, 25, 10));
    expect(parseApiDate('2026-09-25T15:30:00+05:30'), DateTime.utc(2026, 9, 25, 10));
    expect(parseApiDateOrNull(null), isNull);
  });

  group('ApiClient', () {
    late FakeApi api;
    setUp(() => api = FakeApi());

    test('sends the bearer token and paging parameters', () async {
      api.on(
        'GET',
        '/api/notifications/mine',
        (_) => const FakeResponse(200, {
          'items': [
            {'notificationId': 7},
          ],
          'page': 2,
          'pageSize': 10,
          'totalCount': 11,
          'totalPages': 2,
        }),
      );
      final client = fakeApiClient(api, readToken: () => 'jwt-123');

      final page = await client.getPaged(
        '/api/notifications/mine',
        page: 2,
        pageSize: 10,
        item: (json) => json['notificationId'] as int,
      );

      expect(page.items, [7]);
      final request = api.lastTo('GET', '/api/notifications/mine')!;
      expect(request.headers['Authorization'], 'Bearer jwt-123');
      expect(request.query, {'page': '2', 'pageSize': '10'});
    });

    test('sends no Authorization header when signed out', () async {
      api.on('GET', '/api/districts', (_) => const FakeResponse(200, ['Colombo']));
      final client = fakeApiClient(api);
      final districts = await client.get(
        '/api/districts',
        decode: (data) => (data! as List).cast<String>(),
      );
      expect(districts, ['Colombo']);
      expect(api.requests.single.headers.containsKey('Authorization'), isFalse);
    });

    test('a 401 reports the token that was rejected', () async {
      api.on('GET', '/api/users/me', (_) => const FakeResponse(401));
      String? rejected;
      final client = fakeApiClient(
        api,
        readToken: () => 'old-token',
        onUnauthorized: (token) => rejected = token,
      );

      await expectLater(
        client.get('/api/users/me', decode: (d) => d),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)),
      );
      expect(rejected, 'old-token');
    });

    test('maps status codes and bodies to ApiException', () async {
      api
        ..on(
          'POST',
          '/api/auth/login',
          (_) => const FakeResponse(403, {
            'message': 'Your registration was not approved.',
            'reason': 'Plot number could not be verified.',
          }),
        )
        ..offline('GET', '/api/districts');
      final client = fakeApiClient(api);

      final error = await client
          .post('/api/auth/login', body: {'email': 'a@b.lk'}, decode: (d) => d)
          .then<ApiException?>((_) => null, onError: (Object e) => e as ApiException);
      expect(error!.kind, ApiErrorKind.forbidden);
      expect(error.serverMessage, 'Your registration was not approved.');
      expect(error.bodyField('reason'), 'Plot number could not be verified.');

      await expectLater(
        client.get('/api/districts', decode: (d) => d),
        throwsA(isA<ApiException>().having((e) => e.isConnectivity, 'isConnectivity', isTrue)),
      );
    });

    test('a response of the wrong shape becomes an ApiException', () async {
      api.on('GET', '/api/users/me', (_) => const FakeResponse(200, ['not', 'an', 'object']));
      final client = fakeApiClient(api);
      await expectLater(
        client.get('/api/users/me', decode: asJson),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.unknown)),
      );
    });

    test('ignoreBody accepts an empty 204', () async {
      api.on('PUT', '/api/notifications/read-all', (_) => const FakeResponse(204));
      final client = fakeApiClient(api);
      await client.put('/api/notifications/read-all', decode: ApiClient.ignoreBody);
    });
  });
}
