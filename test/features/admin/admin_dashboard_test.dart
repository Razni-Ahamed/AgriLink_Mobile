import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';

Map<String, Object?> adminMetricsJson({int users = 120}) => {
  'totalUsers': users,
  'totalFarms': 40,
  'totalCrops': 75,
  'issuesReported': 30,
  'issuesPending': 4,
  'issuesResolved': 22,
  'harvestVolumeSoldThisMonth': 1250.5,
};

void main() {
  Future<TestApp> start(WidgetTester tester, FakeApi api, {String language = 'en'}) {
    api.on('GET', '/api/users/me', (_) => FakeResponse(200, profileJson(Role.admin)));
    return pumpAgriLink(
      tester,
      api: api,
      session: Session(token: fakeJwt(), role: Role.admin),
      language: language,
    );
  }

  testWidgets('the dashboard shows the platform numbers and the totals chart', (tester) async {
    final api = FakeApi()
      ..on('GET', '/api/admin/metrics', (_) => FakeResponse(200, adminMetricsJson()));
    await start(tester, api);

    expect(find.text('Admin Dashboard'), findsWidgets);
    expect(find.text('Total users'), findsWidgets);
    expect(find.text('120'), findsWidgets);
    expect(find.text('Issues pending review'), findsWidgets);
    expect(find.text('1,250.5 kg'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Platform totals'), 300);
    expect(find.text('Platform totals'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(6));
  });

  testWidgets('the pending issues card opens the pending issues page', (tester) async {
    final api = FakeApi()
      ..on('GET', '/api/admin/metrics', (_) => FakeResponse(200, adminMetricsJson()));
    await start(tester, api);

    await tester.tap(find.byKey(const Key('metric-issues-pending')));
    await tester.pumpAndSettle();
    expect(find.text('Admin Dashboard'), findsNothing);
    expect(find.text('Pending Issues'), findsWidgets);
  });

  testWidgets('pull to refresh loads the numbers again', (tester) async {
    var users = 120;
    final api = FakeApi()
      ..on('GET', '/api/admin/metrics', (_) => FakeResponse(200, adminMetricsJson(users: users)));
    await start(tester, api);
    expect(find.text('120'), findsWidgets);

    users = 121;
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('121'), findsWidgets);
  });

  testWidgets('a failed load shows an error with Try again', (tester) async {
    final api = FakeApi()..offline('GET', '/api/admin/metrics');
    await start(tester, api);
    expect(find.text('Try again'), findsOneWidget);

    api.on('GET', '/api/admin/metrics', (_) => FakeResponse(200, adminMetricsJson()));
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Total users'), findsWidgets);
  });

  testWidgets('the cards fit a narrow screen in Tamil', (tester) async {
    final api = FakeApi()
      ..on('GET', '/api/admin/metrics', (_) => FakeResponse(200, adminMetricsJson()));
    await pumpAgriLink(
      tester,
      api: api..on('GET', '/api/users/me', (_) => FakeResponse(200, profileJson(Role.admin))),
      session: Session(token: fakeJwt(), role: Role.admin),
      language: 'ta',
      screen: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('120'), findsWidgets);
  });
}
