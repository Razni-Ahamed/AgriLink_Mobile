import 'dart:async';

import 'package:agrilink_mobile/core/api/api_exception.dart';
import 'package:agrilink_mobile/core/api/paged.dart';
import 'package:agrilink_mobile/shared/widgets/paged_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

/// Pages of [pageSize] numbers, [total] in all.
Paged<int> pageOf(int page, {int pageSize = 10, int total = 25}) {
  final start = (page - 1) * pageSize;
  final end = (start + pageSize).clamp(0, total);
  return Paged(
    items: [for (var i = start; i < end; i++) i],
    page: page,
    pageSize: pageSize,
    totalCount: total,
    totalPages: (total / pageSize).ceil(),
  );
}

void main() {
  group('PagedListController', () {
    test('loads pages in order until the last one', () async {
      final requested = <int>[];
      final controller = PagedListController<int>(
        loadPage: (page) async {
          requested.add(page);
          return pageOf(page);
        },
      );
      addTearDown(controller.dispose);

      await controller.loadFirstPage();
      expect(controller.items.length, 10);
      expect(controller.hasMore, isTrue);

      await controller.loadMore();
      await controller.loadMore();
      expect(controller.items.length, 25);
      expect(controller.hasMore, isFalse);

      await controller.loadMore();
      expect(requested, [1, 2, 3]);
    });

    test('keeps loaded items after a later page fails, and retries that page', () async {
      var failPage2 = true;
      final controller = PagedListController<int>(
        loadPage: (page) async {
          if (page == 2 && failPage2) {
            throw const ApiException(ApiErrorKind.network);
          }
          return pageOf(page);
        },
      );
      addTearDown(controller.dispose);

      await controller.loadFirstPage();
      await controller.loadMore();
      expect(controller.error, isA<ApiException>());
      expect(controller.items.length, 10);

      failPage2 = false;
      await controller.retry();
      expect(controller.error, isNull);
      expect(controller.items.length, 20);
    });

    test('refresh replaces the list and ignores a slower older response', () async {
      final slow = Completer<Paged<int>>();
      var calls = 0;
      final controller = PagedListController<int>(
        loadPage: (page) {
          calls++;
          return calls == 1 ? slow.future : Future.value(pageOf(1, total: 3));
        },
      );
      addTearDown(controller.dispose);

      unawaited(controller.loadFirstPage());
      await controller.refresh();
      slow.complete(pageOf(1));
      await Future<void>.delayed(Duration.zero);

      expect(controller.items, [0, 1, 2]);
      expect(controller.hasMore, isFalse);
    });

    test('updateWhere changes items in place', () async {
      final controller = PagedListController<int>(loadPage: (page) async => pageOf(page, total: 3));
      addTearDown(controller.dispose);
      await controller.loadFirstPage();
      controller.updateWhere((n) => n == 1, (n) => 100);
      expect(controller.items, [0, 100, 2]);
    });
  });

  testWidgets('PagedListView shows items, then loads more on scroll', (tester) async {
    final controller = PagedListController<int>(
      loadPage: (page) async => pageOf(page, pageSize: 20, total: 45),
    );
    addTearDown(controller.dispose);

    await tester.pumpApp(
      PagedListView<int>(
        controller: controller,
        itemBuilder: (context, item, index) => SizedBox(height: 60, child: Text('Item $item')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Item 0'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Item 44'), 500);
    await tester.pumpAndSettle();
    expect(find.text('Item 44'), findsOneWidget);
    expect(controller.hasMore, isFalse);
  });

  testWidgets('PagedListView shows an error with a retry on the first page', (tester) async {
    var fail = true;
    final controller = PagedListController<int>(
      loadPage: (page) async {
        if (fail) {
          throw const ApiException(ApiErrorKind.network);
        }
        return pageOf(page, total: 2);
      },
    );
    addTearDown(controller.dispose);

    await tester.pumpApp(
      PagedListView<int>(
        controller: controller,
        itemBuilder: (context, item, index) => Text('Item $item'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining("Can't reach the server"), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Item 1'), findsOneWidget);
  });

  testWidgets('PagedListView shows the empty state', (tester) async {
    final controller = PagedListController<int>(loadPage: (page) async => pageOf(page, total: 0));
    addTearDown(controller.dispose);
    await tester.pumpApp(
      PagedListView<int>(
        controller: controller,
        itemBuilder: (context, item, index) => Text('Item $item'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nothing here yet'), findsOneWidget);
  });
}
