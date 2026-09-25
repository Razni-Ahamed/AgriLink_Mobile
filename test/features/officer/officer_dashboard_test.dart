import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:agrilink_mobile/features/officer/data/officer_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';

Map<String, Object?> officerMetricsJson({int pending = 4}) => {
  'district': 'Kandy',
  'departmentName': 'Agriculture Department',
  'pendingInDistrict': pending,
  'reviewedToday': 2,
  'reviewedTotal': 1250,
  'approvedTotal': 1000,
  'rejectedTotal': 250,
};

void main() {
  test('OfficerMetrics reads the API response', () {
    final metrics = OfficerMetrics.fromJson(officerMetricsJson());
    expect(metrics.district, 'Kandy');
    expect(metrics.departmentName, 'Agriculture Department');
    expect(metrics.pendingInDistrict, 4);
    expect(metrics.reviewedToday, 2);
    expect(metrics.reviewedTotal, 1250);
    expect(metrics.approvedTotal, 1000);
    expect(metrics.rejectedTotal, 250);
  });

  test('OfficerMetrics treats missing numbers as zero', () {
    final metrics = OfficerMetrics.fromJson({'district': 'Kandy'});
    expect(metrics.pendingInDistrict, 0);
    expect(metrics.departmentName, '');
  });

  Future<TestApp> start(WidgetTester tester, FakeApi api, {String language = 'en'}) {
    api.on('GET', '/api/users/me', (_) => FakeResponse(200, profileJson(Role.officer)));
    return pumpAgriLink(
      tester,
      api: api,
      session: Session(token: fakeJwt(), role: Role.officer),
      language: language,
    );
  }

  testWidgets('the dashboard shows the district, department and the numbers', (tester) async {
    final api = FakeApi()
      ..on('GET', '/api/officer/metrics', (_) => FakeResponse(200, officerMetricsJson()));
    await start(tester, api);

    expect(find.text('Officer Dashboard'), findsWidgets);
    expect(find.text('Kandy'), findsOneWidget);
    expect(find.text('Agriculture Department'), findsOneWidget);
    expect(find.text('Pending in my district'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('1,250'), findsOneWidget);
    expect(find.text('Reviewed today'), findsOneWidget);
  });

  testWidgets('tapping pending opens the pending issues page', (tester) async {
    final api = FakeApi()
      ..on('GET', '/api/officer/metrics', (_) => FakeResponse(200, officerMetricsJson()));
    await start(tester, api);

    await tester.tap(find.byKey(const Key('metric-pending')));
    await tester.pumpAndSettle();
    expect(find.text('Pending Issues'), findsWidgets);
    expect(find.text('Officer Dashboard'), findsNothing);
  });

  testWidgets('pull to refresh loads the numbers again', (tester) async {
    var pending = 4;
    final api = FakeApi()
      ..on(
        'GET',
        '/api/officer/metrics',
        (_) => FakeResponse(200, officerMetricsJson(pending: pending)),
      );
    await start(tester, api);
    expect(find.text('4'), findsOneWidget);

    pending = 9;
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('9'), findsOneWidget);
  });

  testWidgets('a failed load shows an error with Try again', (tester) async {
    final api = FakeApi()..offline('GET', '/api/officer/metrics');
    await start(tester, api);
    expect(find.text('Try again'), findsOneWidget);

    api.on('GET', '/api/officer/metrics', (_) => FakeResponse(200, officerMetricsJson()));
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Kandy'), findsOneWidget);
  });
}
