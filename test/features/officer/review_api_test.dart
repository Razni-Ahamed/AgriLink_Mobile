import 'package:agrilink_mobile/core/api/api_exception.dart';
import 'package:agrilink_mobile/features/issues/data/issue_enums.dart';
import 'package:agrilink_mobile/features/officer/data/review_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../issues/issue_fixtures.dart';

Map<String, Object?> pagedIssues(List<Map<String, Object?>> items) => {
  'items': items,
  'page': 1,
  'pageSize': 20,
  'totalCount': items.length,
  'totalPages': 1,
};

void main() {
  late FakeApi fake;
  late ReviewApi api;

  setUp(() {
    fake = FakeApi();
    api = ReviewApi(fakeApiClient(fake));
  });

  group('the lists', () {
    test('pending reads a page of issues, with the reporter an officer sees', () async {
      fake.on(
        'GET',
        '/api/issues/pending',
        (_) => FakeResponse(
          200,
          pagedIssues([
            {...issueJson(), 'reporterName': 'Nimal Perera'},
          ]),
        ),
      );
      final page = await api.pending();
      expect(page.items.single.reporterName, 'Nimal Perera');
      expect(page.items.single.advisoryId, 21);
      expect(page.items.single.severity, IssueSeverity.high);
      expect(fake.lastTo('GET', '/api/issues/pending')!.query, {'page': '1', 'pageSize': '20'});
    });

    test('reviewed and all use their own endpoints', () async {
      fake
        ..on('GET', '/api/issues/reviewed', (_) => FakeResponse(200, pagedIssues([issueJson()])))
        ..on('GET', '/api/issues', (_) => FakeResponse(200, pagedIssues([issueJson(id: 9)])));
      expect((await api.reviewed()).items.single.id, 7);
      expect((await api.all(page: 2)).items.single.id, 9);
      expect(fake.lastTo('GET', '/api/issues')!.query['page'], '2');
    });
  });

  group('the decision', () {
    Map<String, Object?> decided(String status) => farmerAdvisoryJson(
      status: status,
      extra: {
        'reviewedByName': 'Officer One',
        'reviewedAt': '2026-09-21T09:00:00Z',
        'reviewNote': 'Fine',
      },
    );

    test('approve posts the request to the advisory and reads the updated advisory', () async {
      fake.on('POST', '/api/advisories/21/approve', (_) => FakeResponse(200, decided('Approved')));
      final advisory = await api.approve(
        21,
        const ReviewAdvisoryRequest(note: 'Fine', treatment: 'Spray'),
      );
      expect(advisory.status, AdvisoryStatus.approved);
      expect(advisory.reviewedByName, 'Officer One');
      expect(fake.lastTo('POST', '/api/advisories/21/approve')!.json, {
        'note': 'Fine',
        'treatment': 'Spray',
      });
    });

    test('reject posts to its own endpoint, with the disease correction', () async {
      fake.on('POST', '/api/advisories/21/reject', (_) => FakeResponse(200, decided('Rejected')));
      final advisory = await api.reject(
        21,
        const ReviewAdvisoryRequest(diseaseKey: 'rust', treatment: 'Remove leaves'),
      );
      expect(advisory.status, AdvisoryStatus.rejected);
      expect(fake.lastTo('POST', '/api/advisories/21/reject')!.json, {
        'treatment': 'Remove leaves',
        'diseaseKey': 'rust',
      });
    });

    test('an empty review sends an empty body', () async {
      fake.on('POST', '/api/advisories/21/approve', (_) => FakeResponse(200, decided('Approved')));
      await api.approve(21, const ReviewAdvisoryRequest());
      expect(fake.lastTo('POST', '/api/advisories/21/approve')!.json, isEmpty);
    });

    test('an advisory someone else already reviewed comes back as the server\'s message', () async {
      fake.on(
        'POST',
        '/api/advisories/21/approve',
        (_) => const FakeResponse(400, {
          'message': 'Only advisories awaiting review can be reviewed.',
        }),
      );
      await expectLater(
        api.approve(21, const ReviewAdvisoryRequest()),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.badRequest)
              .having(
                (e) => e.serverMessage,
                'message',
                'Only advisories awaiting review can be reviewed.',
              ),
        ),
      );
    });
  });
}
