import 'package:agrilink_mobile/app/router/app_router.dart';
import 'package:agrilink_mobile/app/router/app_routes.dart';
import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';
import 'farmer_backend.dart';
import 'farmer_fixtures.dart';

String currentPath(TestApp app) =>
    app.container.read(routerProvider).routerDelegate.currentConfiguration.uri.path;

void main() {
  late FarmerBackend backend;

  setUp(() => backend = FarmerBackend(FakeApi()));

  Finder submit(String key) => find.byKey(Key(key));

  group('farms list', () {
    testWidgets('shows each farm with its district and area', (tester) async {
      await pumpFarmer(tester, backend);
      expect(find.text('Your Farms'), findsOneWidget);
      expect(find.text('Green Acres'), findsOneWidget);
      expect(find.text('Kandy'), findsOneWidget);
      expect(find.text('12.5 acres'), findsOneWidget);
    });

    testWidgets('an empty list invites the farmer to add a farm', (tester) async {
      backend.farms.clear();
      await pumpFarmer(tester, backend);
      expect(find.textContaining("You don't have any farms yet"), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'New Farm'), findsOneWidget);
    });

    testWidgets('a failed load can be tried again', (tester) async {
      backend.api.offline('GET', '/api/farms');
      await pumpFarmer(tester, backend);
      expect(find.textContaining("Can't reach the server"), findsOneWidget);

      backend.api.on('GET', '/api/farms', (_) => FakeResponse(200, [farmJson()]));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Green Acres'), findsOneWidget);
    });

    testWidgets('pull to refresh reloads the list', (tester) async {
      await pumpFarmer(tester, backend);
      backend.farms.add(farmJson(id: 2, name: 'Hill Farm'));
      await tester.fling(find.byKey(const Key('farms-list')), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Hill Farm'), findsOneWidget);
    });
  });

  group('adding a farm', () {
    Future<void> openForm(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('new-farm')));
      await tester.pumpAndSettle();
    }

    testWidgets('checks the fields before sending anything', (tester) async {
      final app = await pumpFarmer(tester, backend);
      await openForm(tester);

      await tester.tapVisible(submit('farm-submit'));
      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('District is required'), findsOneWidget);
      expect(find.text('Area must be greater than 0'), findsOneWidget);
      expect(app.api.lastTo('POST', '/api/farms'), isNull);

      await tester.fill(find.byKey(const Key('farm-area')), '100001');
      expect(find.text('Area is too large'), findsOneWidget);
      await tester.fill(find.byKey(const Key('farm-area')), '0');
      expect(find.text('Area must be greater than 0'), findsOneWidget);
    });

    testWidgets('saves the farm, closes the form and shows it in the list', (tester) async {
      final app = await pumpFarmer(tester, backend);
      await openForm(tester);

      await tester.fill(find.byKey(const Key('farm-name')), '  Hill Farm ');
      await tester.tapVisible(find.byKey(const Key('farm-district')));
      await tester.tap(find.text('Galle'));
      await tester.pumpAndSettle();
      // A comma from a phone keyboard counts as a decimal point.
      await tester.fill(find.byKey(const Key('farm-area')), '3,5');
      await tester.tapVisible(submit('farm-submit'));

      expect(app.api.lastTo('POST', '/api/farms')!.json, {
        'name': 'Hill Farm',
        'district': 'Galle',
        'area': 3.5,
      });
      expect(find.byKey(const Key('farm-name')), findsNothing);
      expect(find.text('Hill Farm'), findsOneWidget);
      expect(find.text('Farm created.'), findsOneWidget);
    });

    testWidgets('a rejected farm keeps what was typed and shows the reason', (tester) async {
      backend.api.on(
        'POST',
        '/api/farms',
        (_) => const FakeResponse(400, {
          'message': "District must be one of Sri Lanka's 25 administrative districts.",
        }),
      );
      await pumpFarmer(tester, backend);
      await openForm(tester);

      await tester.fill(find.byKey(const Key('farm-name')), 'Hill Farm');
      await tester.tapVisible(find.byKey(const Key('farm-district')));
      await tester.tap(find.text('Galle'));
      await tester.pumpAndSettle();
      await tester.fill(find.byKey(const Key('farm-area')), '3');
      await tester.tapVisible(submit('farm-submit'));

      expect(find.textContaining('District must be one of'), findsOneWidget);
      expect(find.byKey(const Key('farm-name')), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.byKey(const Key('farm-name'))).controller!.text,
        'Hill Farm',
      );
      expect(find.text('Hill Farm'), findsOneWidget);
    });

    testWidgets('no connection is explained and the form stays open', (tester) async {
      backend.api.offline('POST', '/api/farms');
      await pumpFarmer(tester, backend);
      await openForm(tester);

      await tester.fill(find.byKey(const Key('farm-name')), 'Hill Farm');
      await tester.tapVisible(find.byKey(const Key('farm-district')));
      await tester.tap(find.text('Galle'));
      await tester.pumpAndSettle();
      await tester.fill(find.byKey(const Key('farm-area')), '3');
      await tester.tapVisible(submit('farm-submit'));

      expect(find.textContaining("Can't reach the server"), findsOneWidget);
      expect(find.byKey(const Key('farm-name')), findsOneWidget);
    });
  });

  group('farm detail', () {
    Future<TestApp> openFarm(WidgetTester tester) async {
      final app = await pumpFarmer(tester, backend);
      await tester.tap(find.text('Green Acres'));
      await tester.pumpAndSettle();
      expect(currentPath(app), '/farms/1');
      return app;
    }

    testWidgets('shows the farm and its fields', (tester) async {
      await openFarm(tester);
      expect(find.text('Green Acres'), findsWidgets);
      expect(find.text('Kandy'), findsOneWidget);
      expect(find.text('North Field'), findsOneWidget);
      expect(find.text('4 acres'), findsOneWidget);
    });

    testWidgets('a farm with no fields says so', (tester) async {
      backend.fields.clear();
      await openFarm(tester);
      expect(find.text('No fields yet. Add one to get started.'), findsOneWidget);
    });

    testWidgets('a farm that does not exist says so', (tester) async {
      final app = await pumpFarmer(tester, backend);
      app.container.read(routerProvider).go('/farms/7');
      await tester.pumpAndSettle();
      expect(find.text('Farm not found.'), findsOneWidget);
    });

    testWidgets('adds a field', (tester) async {
      final app = await openFarm(tester);
      await tester.tap(find.byKey(const Key('add-field')));
      await tester.pumpAndSettle();

      await tester.tapVisible(submit('field-submit'));
      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Area must be greater than 0'), findsOneWidget);

      await tester.fill(find.byKey(const Key('field-name')), 'South Field');
      await tester.fill(find.byKey(const Key('field-area')), '2.25');
      await tester.tapVisible(submit('field-submit'));

      expect(app.api.lastTo('POST', '/api/farms/1/fields')!.json, {
        'name': 'South Field',
        'area': 2.25,
      });
      expect(find.text('South Field'), findsOneWidget);
      expect(find.text('Field added.'), findsOneWidget);
    });

    testWidgets('edits the farm, starting from its current values', (tester) async {
      final app = await openFarm(tester);
      await tester.tap(find.byKey(const Key('edit-farm')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Farm'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.byKey(const Key('farm-name'))).controller!.text,
        'Green Acres',
      );
      expect(
        tester.widget<TextFormField>(find.byKey(const Key('farm-area'))).controller!.text,
        '12.5',
      );

      await tester.fill(find.byKey(const Key('farm-name')), 'Green Acres North');
      await tester.tapVisible(submit('farm-submit'));

      expect(app.api.lastTo('PUT', '/api/farms/1')!.json, {
        'name': 'Green Acres North',
        'district': 'Kandy',
        'area': 12.5,
      });
      expect(find.text('Green Acres North'), findsWidgets);
      expect(find.text('Farm updated.'), findsOneWidget);
    });

    testWidgets('deletes the farm after a confirmation', (tester) async {
      final app = await openFarm(tester);
      await tester.tap(find.byKey(const Key('delete-farm')));
      await tester.pumpAndSettle();
      expect(find.text('Delete this farm? This cannot be undone.'), findsOneWidget);
      expect(app.api.lastTo('DELETE', '/api/farms/1'), isNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(app.api.lastTo('DELETE', '/api/farms/1'), isNotNull);
      expect(currentPath(app), AppRoutes.farms);
      expect(find.text('Farm deleted.'), findsOneWidget);
      expect(find.text('Green Acres'), findsNothing);
    });

    testWidgets('cancelling the confirmation deletes nothing', (tester) async {
      final app = await openFarm(tester);
      await tester.tap(find.byKey(const Key('delete-farm')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(app.api.lastTo('DELETE', '/api/farms/1'), isNull);
      expect(currentPath(app), '/farms/1');
    });

    testWidgets("a farm with crops can't be deleted, and the server's message is shown", (
      tester,
    ) async {
      backend.api.on(
        'DELETE',
        '/api/farms/1',
        (_) => const FakeResponse(400, {
          'message': 'Cannot delete a farm that has crops planted. Remove crops first.',
        }),
      );
      final app = await openFarm(tester);
      await tester.tap(find.byKey(const Key('delete-farm')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('Cannot delete a farm that has crops planted. Remove crops first.'),
        findsOneWidget,
      );
      expect(currentPath(app), '/farms/1');
      // Still there, and the buttons work again.
      expect(find.text('North Field'), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(find.byKey(const Key('delete-farm'))).onPressed,
        isNotNull,
      );
    });
  });

  group('field detail and planting a crop', () {
    Future<TestApp> openField(WidgetTester tester) async {
      final app = await pumpFarmer(tester, backend);
      await tester.tap(find.text('Green Acres'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('North Field'));
      await tester.pumpAndSettle();
      expect(currentPath(app), '/farms/1/fields/10');
      return app;
    }

    Future<void> pickDate(WidgetTester tester, String key, {int monthsAhead = 0, int? day}) async {
      await tester.tapVisible(find.byKey(Key(key)));
      for (var i = 0; i < monthsAhead; i++) {
        await tester.tap(find.byTooltip('Next month'));
        await tester.pumpAndSettle();
      }
      if (day != null) {
        await tester.tap(find.text('$day'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    testWidgets('lists the crops with their status', (tester) async {
      await openField(tester);
      expect(find.text('North Field'), findsWidgets);
      expect(find.text('Green Gram'), findsOneWidget);
      expect(find.text('MI 5'), findsOneWidget);
      expect(find.text('Seeded'), findsOneWidget);
    });

    testWidgets('a field with no crops says so', (tester) async {
      backend.crops.clear();
      await openField(tester);
      expect(
        find.text('No crops planted in this field yet. Plant one to get started.'),
        findsOneWidget,
      );
    });

    testWidgets('a field that does not exist says so', (tester) async {
      final app = await pumpFarmer(tester, backend);
      app.container.read(routerProvider).go('/farms/1/fields/15');
      await tester.pumpAndSettle();
      expect(find.text('Field not found.'), findsOneWidget);
    });

    testWidgets('checks every field of the planting form', (tester) async {
      final app = await openField(tester);
      await tester.tap(find.byKey(const Key('plant-crop')));
      await tester.pumpAndSettle();

      await tester.tapVisible(submit('crop-submit'));
      expect(find.text('Crop type is required'), findsOneWidget);
      expect(find.text('Planting date is required'), findsOneWidget);
      expect(find.text('Expected harvest date is required'), findsOneWidget);
      expect(find.text('Quantity must be greater than 0'), findsOneWidget);
      expect(app.api.lastTo('POST', '/api/fields/10/crops'), isNull);

      // A harvest on the day of planting is too early.
      await pickDate(tester, 'crop-planting-date');
      await pickDate(tester, 'crop-harvest-date');
      expect(find.text('Expected harvest date must be after the planting date'), findsOneWidget);

      // Fixing the date clears the message straight away, without another tap on save.
      await pickDate(tester, 'crop-harvest-date', monthsAhead: 1, day: 15);
      expect(find.text('Expected harvest date must be after the planting date'), findsNothing);

      await tester.fill(find.byKey(const Key('crop-quantity')), '1000001');
      expect(find.text('Quantity is too large'), findsOneWidget);
    });

    testWidgets('plants a crop and lists it', (tester) async {
      final app = await openField(tester);
      await tester.tap(find.byKey(const Key('plant-crop')));
      await tester.pumpAndSettle();

      await tester.tapVisible(find.byKey(const Key('crop-type')));
      await tester.enterText(find.byKey(const Key('crop-type-search')), 'tom');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('crop-type-Paddy')), findsNothing);
      await tester.tap(find.byKey(const Key('crop-type-Tomato')));
      await tester.pumpAndSettle();

      await tester.fill(find.byKey(const Key('crop-variety')), 'Thilina');
      await pickDate(tester, 'crop-planting-date');
      await pickDate(tester, 'crop-harvest-date', monthsAhead: 1, day: 15);
      await tester.fill(find.byKey(const Key('crop-quantity')), '480.5');
      await tester.tapVisible(submit('crop-submit'));

      final now = DateTime.now();
      final harvest = DateTime(now.year, now.month + 1, 15);
      String day(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      expect(app.api.lastTo('POST', '/api/fields/10/crops')!.json, {
        'cropType': 'Tomato',
        'variety': 'Thilina',
        'plantingDate': day(now),
        'expectedHarvestDate': day(harvest),
        'expectedQuantity': 480.5,
      });
      expect(find.byKey(const Key('crop-type')), findsNothing);
      expect(find.text('Tomato'), findsOneWidget);
      expect(find.text('Thilina'), findsOneWidget);
      expect(find.text('Crop planted.'), findsOneWidget);
    });

    testWidgets('a rejected planting keeps the form and shows the reason', (tester) async {
      backend.api.on(
        'POST',
        '/api/fields/10/crops',
        (_) => const FakeResponse(400, {
          'message': 'Crop type must be one of the supported crop types.',
        }),
      );
      await openField(tester);
      await tester.tap(find.byKey(const Key('plant-crop')));
      await tester.pumpAndSettle();

      await tester.tapVisible(find.byKey(const Key('crop-type')));
      await tester.tap(find.byKey(const Key('crop-type-Paddy')));
      await tester.pumpAndSettle();
      await pickDate(tester, 'crop-planting-date');
      await pickDate(tester, 'crop-harvest-date', monthsAhead: 1, day: 15);
      await tester.fill(find.byKey(const Key('crop-quantity')), '100');
      await tester.tapVisible(submit('crop-submit'));

      expect(find.text('Crop type must be one of the supported crop types.'), findsOneWidget);
      expect(find.byKey(const Key('crop-quantity')), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.byKey(const Key('crop-quantity'))).controller!.text,
        '100',
      );
    });
  });

  group('crop detail', () {
    Future<TestApp> openCrop(WidgetTester tester) async {
      final app = await pumpFarmer(tester, backend);
      await tester.tap(find.text('Green Acres'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('North Field'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Green Gram'));
      await tester.pumpAndSettle();
      expect(currentPath(app), '/farms/1/fields/10/crops/100');
      return app;
    }

    testWidgets('shows the crop’s details and current status', (tester) async {
      await openCrop(tester);
      expect(find.text('Green Gram'), findsWidgets);
      expect(find.text('MI 5'), findsOneWidget);
      expect(find.text('250 kg'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('status-Seeded'))).selected, isTrue);
    });

    testWidgets('changes the status after asking', (tester) async {
      final app = await openCrop(tester);
      await tester.tap(find.byKey(const Key('status-Growing')));
      await tester.pumpAndSettle();
      expect(find.text('Change this crop from Seeded to Growing?'), findsOneWidget);
      expect(app.api.lastTo('PUT', '/api/crops/100'), isNull);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(app.api.lastTo('PUT', '/api/crops/100')!.json, {'status': 'Growing'});
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('status-Growing'))).selected, isTrue);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('status-Seeded'))).selected, isFalse);
      expect(find.text('Status updated.'), findsOneWidget);
    });

    testWidgets('cancelling leaves the status alone', (tester) async {
      final app = await openCrop(tester);
      await tester.tap(find.byKey(const Key('status-Harvested')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(app.api.lastTo('PUT', '/api/crops/100'), isNull);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('status-Seeded'))).selected, isTrue);
    });

    testWidgets('the current status is not a change', (tester) async {
      await openCrop(tester);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('status-Seeded'))).onSelected, isNull);
    });

    testWidgets('a failed change says so and keeps the status', (tester) async {
      final app = await openCrop(tester);
      backend.api.offline('PUT', '/api/crops/100');
      await tester.tap(find.byKey(const Key('status-Growing')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.textContaining("Can't reach the server"), findsOneWidget);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('status-Seeded'))).selected, isTrue);
      expect(app.api.lastTo('PUT', '/api/crops/100'), isNotNull);
      // Free to try again.
      expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('status-Growing'))).onSelected,
        isNotNull,
      );
    });

    testWidgets('the status change shows in the field’s crop list', (tester) async {
      final app = await openCrop(tester);
      await tester.tap(find.byKey(const Key('status-Harvested')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      app.container.read(routerProvider).go('/farms/1/fields/10');
      await tester.pumpAndSettle();
      expect(find.text('Harvested'), findsOneWidget);
      expect(find.text('Seeded'), findsNothing);
    });
  });

  group('links and access', () {
    testWidgets('a link with a bad id shows the not-found page', (tester) async {
      final app = await pumpFarmer(tester, backend);
      app.container.read(routerProvider).go('/farms/abc');
      await tester.pumpAndSettle();
      expect(find.text("We couldn't find what you were looking for."), findsOneWidget);
    });

    testWidgets('a buyer cannot open the farmer pages', (tester) async {
      final app = await pumpAgriLink(
        tester,
        api: backend.api
          ..on('GET', '/api/users/me', (_) => FakeResponse(200, profileJson(Role.buyer))),
        session: Session(token: fakeJwt(), role: Role.buyer),
      );
      for (final path in [
        '/farms',
        '/farms/1',
        '/farms/1/fields/10',
        '/farms/1/fields/10/crops/100',
      ]) {
        app.container.read(routerProvider).go(path);
        await tester.pumpAndSettle();
        expect(currentPath(app), AppRoutes.marketplace, reason: path);
      }
    });
  });

  group('small screens in Sinhala and Tamil with large text', () {
    for (final language in ['si', 'ta']) {
      testWidgets('every farm screen and form fits in $language', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final app = await pumpFarmer(
          tester,
          backend,
          language: language,
          screen: const Size(320, 640),
        );
        void noOverflow(String where) {
          final error = tester.takeException();
          final detail = error is FlutterError
              ? error.diagnostics.map((node) => node.toString()).take(12).join(' | ')
              : '';
          expect(error, isNull, reason: '$language: $where $detail');
        }

        noOverflow('farms list');
        await tester.tap(find.byKey(const Key('new-farm')));
        await tester.pumpAndSettle();
        noOverflow('farm form');
        await tester.tapVisible(submit('farm-submit'));
        noOverflow('farm form errors');
        await tester.ensureVisible(find.byIcon(Icons.close));
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        app.container.read(routerProvider).go('/farms/1');
        await tester.pumpAndSettle();
        noOverflow('farm detail');
        app.container.read(routerProvider).go('/farms/1/fields/10');
        await tester.pumpAndSettle();
        noOverflow('field detail');
        await tester.tap(find.byKey(const Key('plant-crop')));
        await tester.pumpAndSettle();
        noOverflow('crop form');
        await tester.tapVisible(submit('crop-submit'));
        noOverflow('crop form errors');
        await tester.ensureVisible(find.byIcon(Icons.close));
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        app.container.read(routerProvider).go('/farms/1/fields/10/crops/100');
        await tester.pumpAndSettle();
        noOverflow('crop detail');
      });
    }
  });
}
