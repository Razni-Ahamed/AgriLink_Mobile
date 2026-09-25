import 'dart:typed_data';

import 'package:agrilink_mobile/core/api/api_client.dart';
import 'package:agrilink_mobile/core/api/api_exception.dart';
import 'package:agrilink_mobile/features/issues/data/crop_issue.dart';
import 'package:agrilink_mobile/features/issues/data/issue_enums.dart';
import 'package:agrilink_mobile/features/issues/data/issues_api.dart';
import 'package:agrilink_mobile/shared/media/photo_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import 'issue_fixtures.dart';

/// Records each request's options (to check timeouts) and passes it on to the fake API.
class _SpyAdapter implements HttpClientAdapter {
  _SpyAdapter(this.inner);

  final FakeApi inner;
  final List<RequestOptions> seen = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    seen.add(options);
    return inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}

const _request = CreateCropIssueRequest(
  cropId: 3,
  title: 'Yellow leaves',
  description: 'The lower leaves are turning yellow.',
  severity: IssueSeverity.high,
);

void main() {
  late FakeApi fake;
  late _SpyAdapter spy;
  late IssuesApi api;

  setUp(() {
    fake = FakeApi();
    spy = _SpyAdapter(fake);
    api = IssuesApi(
      ApiClient(
        createDio(
          baseUrl: 'https://api.test',
          readToken: () => 'token',
          onUnauthorized: (_) {},
          adapter: spy,
        ),
      ),
    );
  });

  test('mine asks for one page and reads the paged envelope', () async {
    fake.on(
      'GET',
      '/api/issues/mine',
      (_) => FakeResponse(200, {
        'items': [
          issueJson(),
          issueJson(id: 8, hasPhoto: false, advisoryId: null, advisoryStatus: null),
        ],
        'page': 2,
        'pageSize': 2,
        'totalCount': 5,
        'totalPages': 3,
      }),
    );

    final page = await api.mine(page: 2, pageSize: 2);

    expect(fake.lastTo('GET', '/api/issues/mine')!.query, {'page': '2', 'pageSize': '2'});
    expect(page.items.map((issue) => issue.id), [7, 8]);
    expect(page.items.last.hasPhoto, isFalse);
    expect(page.hasMore, isTrue);
    expect(page.totalCount, 5);
  });

  test('create sends the JSON body and waits longer than the default', () async {
    fake.on('POST', '/api/issues', (_) => FakeResponse(201, issueJson(id: 30)));

    final issue = await api.create(_request);

    final sent = fake.lastTo('POST', '/api/issues')!;
    expect(sent.json, {
      'cropId': 3,
      'title': 'Yellow leaves',
      'description': 'The lower leaves are turning yellow.',
      'severity': 'High',
    });
    expect(sent.headers['Authorization'], 'Bearer token');
    expect(issue.id, 30);
    expect(spy.seen.single.receiveTimeout, IssuesApi.submitTimeout);
  });

  test('createWithPhoto sends multipart form fields and the photo', () async {
    fake.on('POST', '/api/issues/with-photo', (_) => FakeResponse(201, issueJson(id: 31)));
    final photo = PickedPhoto(Uint8List.fromList([1, 2, 3, 4]));

    final issue = await api.createWithPhoto(_request, photo);

    final sent = fake.lastTo('POST', '/api/issues/with-photo')!;
    final form = sent.body! as FormData;
    expect(Map.fromEntries(form.fields), {
      'cropId': '3',
      'title': 'Yellow leaves',
      'description': 'The lower leaves are turning yellow.',
      'severity': 'High',
    });
    final file = form.files.single;
    expect(file.key, 'photo');
    expect(file.value.filename, 'photo.jpg');
    expect(file.value.length, 4);
    expect(file.value.contentType.toString(), 'image/jpeg');
    expect(issue.id, 31);
    // The analysis runs before the API answers: the default 45 s wait would give up too soon.
    expect(spy.seen.single.receiveTimeout, greaterThanOrEqualTo(const Duration(seconds: 90)));
  });

  test('other calls keep the default timeout', () async {
    fake.on(
      'GET',
      '/api/issues/mine',
      (_) => const FakeResponse(200, {
        'items': <Object?>[],
        'page': 1,
        'pageSize': 20,
        'totalCount': 0,
        'totalPages': 0,
      }),
    );

    await api.mine();

    expect(spy.seen.single.receiveTimeout, isNot(IssuesApi.submitTimeout));
  });

  test('a rule the server rejects comes back with its message', () async {
    fake.on(
      'POST',
      '/api/issues/with-photo',
      (_) => const FakeResponse(400, {'message': 'The photo is larger than 5 MB.'}),
    );

    await expectLater(
      api.createWithPhoto(_request, PickedPhoto(Uint8List(1))),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.badRequest)
            .having((e) => e.serverMessage, 'message', 'The photo is larger than 5 MB.'),
      ),
    );
  });

  test('advisory reads the response', () async {
    fake.on('GET', '/api/advisories/21', (_) => FakeResponse(200, farmerAdvisoryJson()));

    final advisory = await api.advisory(21);

    expect(advisory.id, 21);
    expect(advisory.issueTitle, 'Yellow leaves');
  });

  test('a photo is fetched with the token, as raw bytes', () async {
    // The fake answers with JSON text; what matters is that it arrives as bytes, unparsed.
    fake.on('GET', '/api/issues/7/images/9', (_) => const FakeResponse(200, 'PNG'));

    final bytes = await api.photoBytes('/api/issues/7/images/9');

    expect(bytes, isA<Uint8List>());
    expect(String.fromCharCodes(bytes), '"PNG"');
    expect(fake.lastTo('GET', '/api/issues/7/images/9')!.headers['Authorization'], 'Bearer token');
    expect(spy.seen.single.responseType, ResponseType.bytes);
  });

  test('a photo that is gone is a not-found error', () async {
    fake.on('GET', '/api/issues/7/images/9', (_) => const FakeResponse(404));

    await expectLater(
      api.photoBytes('/api/issues/7/images/9'),
      throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.notFound)),
    );
  });

  test('a draft advisory is a 404 for a farmer, which the screen treats as "not yet"', () async {
    fake.on('GET', '/api/advisories/21', (_) => const FakeResponse(404));

    await expectLater(
      api.advisory(21),
      throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.notFound)),
    );
  });
}
