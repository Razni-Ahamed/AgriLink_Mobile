import 'package:agrilink_mobile/app/router/app_routes.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';
import 'marketplace_fixtures.dart';
import 'marketplace_test_helpers.dart';

void main() {
  FakeApi apiWithListings() => marketplaceFakeApi(Role.buyer)
    ..on(
      'GET',
      '/api/harvests',
      (_) => FakeResponse(200, [
        listingJson(id: 1, pricePerUnit: 80),
        listingJson(id: 2, cropType: 'Rubber', variety: 'RRIC 100', pricePerUnit: 150),
      ]),
    );

  testWidgets('shows each active listing with its price and what is left', (tester) async {
    await pumpMarketplace(
      tester,
      role: Role.buyer,
      api: apiWithListings(),
      path: AppRoutes.marketplace,
    );

    expect(find.byKey(const Key('harvest-1')), findsOneWidget);
    expect(find.byKey(const Key('harvest-2')), findsOneWidget);
    expect(find.text('RRIC 100'), findsOneWidget);
    expect(find.text('Rs 150/unit'), findsOneWidget);
    expect(find.text('400 kg avail.'), findsNWidgets(2));
    expect(find.text('Wariyapola, Kurunegala'), findsNWidgets(2));
  });

  testWidgets('crop and district go to the server; the price range is applied here', (
    tester,
  ) async {
    final app = await pumpMarketplace(
      tester,
      role: Role.buyer,
      api: apiWithListings(),
      path: AppRoutes.marketplace,
    );

    await tester.tap(find.byKey(const Key('open-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter-crop')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rubber').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter-district')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kurunegala').last);
    await tester.pumpAndSettle();
    await tester.fill(find.byKey(const Key('filter-min-price')), '100');
    await tester.tapVisible(find.byKey(const Key('filter-apply')));

    expect(app.api.lastTo('GET', '/api/harvests')!.query, {
      'cropType': 'Rubber',
      'district': 'Kurunegala',
    });
    // The fake ignores the filters, so only the on-device price filter narrows the list.
    expect(find.byKey(const Key('harvest-1')), findsNothing);
    expect(find.byKey(const Key('harvest-2')), findsOneWidget);
    // Three filters are on.
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('no match shows the empty state, and clearing the filters brings them back', (
    tester,
  ) async {
    final app = await pumpMarketplace(
      tester,
      role: Role.buyer,
      api: apiWithListings(),
      path: AppRoutes.marketplace,
    );

    await tester.tap(find.byKey(const Key('open-filters')));
    await tester.pumpAndSettle();
    await tester.fill(find.byKey(const Key('filter-max-price')), '10');
    await tester.tapVisible(find.byKey(const Key('filter-apply')));

    expect(find.text('No listings match your filters right now.'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('harvest-1')), findsOneWidget);
    expect(app.api.lastTo('GET', '/api/harvests')!.query, isEmpty);
  });

  testWidgets('a failed load offers Try again', (tester) async {
    final api = marketplaceFakeApi(Role.farmer)..offline('GET', '/api/harvests');
    await pumpMarketplace(tester, role: Role.farmer, api: api, path: AppRoutes.marketplace);

    expect(find.text('Try again'), findsOneWidget);
    api.on('GET', '/api/harvests', (_) => FakeResponse(200, [listingJson()]));
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('harvest-7')), findsOneWidget);
  });
}
