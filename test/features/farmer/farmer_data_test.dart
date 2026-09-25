import 'package:agrilink_mobile/core/api/api_exception.dart';
import 'package:agrilink_mobile/features/farmer/data/crop.dart';
import 'package:agrilink_mobile/features/farmer/data/crops_api.dart';
import 'package:agrilink_mobile/features/farmer/data/farm.dart';
import 'package:agrilink_mobile/features/farmer/data/farms_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import 'farmer_fixtures.dart';

void main() {
  group('models', () {
    test('a farm reads the API fields, and a whole-number area becomes a double', () {
      final farm = Farm.fromJson(farmJson(area: 12));
      expect(farm.id, 1);
      expect(farm.name, 'Green Acres');
      expect(farm.district, 'Kandy');
      expect(farm.area, 12.0);
      expect(farm.createdAt, DateTime.utc(2026, 8, 1, 6));
    });

    test('a field belongs to its farm', () {
      final field = FarmField.fromJson(fieldJson(id: 11, farmId: 3, area: 0.5));
      expect((field.id, field.farmId, field.area), (11, 3, 0.5));
    });

    test('a crop reads its dates as calendar days, not as instants', () {
      final crop = Crop.fromJson(cropJson(status: 'Growing'));
      expect(crop.plantingDate, DateTime(2026, 9));
      expect(crop.plantingDate.isUtc, isFalse);
      expect(crop.expectedHarvestDate, DateTime(2026, 11, 15));
      expect(crop.status, CropStatus.growing);
      expect(crop.expectedQuantity, 250.0);
    });

    test('a crop with no variety has an empty one', () {
      final json = cropJson()..['variety'] = null;
      expect(Crop.fromJson(json).variety, '');
    });

    test('an unknown crop status is a clear error', () {
      expect(() => Crop.fromJson(cropJson(status: 'Rotten')), throwsFormatException);
    });

    test('the crop summary carries its field and farm', () {
      final crop = FarmerCrop.fromJson(farmerCropJson());
      expect(
        (crop.fieldName, crop.farmName, crop.district),
        ('North Field', 'Green Acres', 'Kandy'),
      );
      expect(crop.status, CropStatus.growing);
    });

    test('days are written and read as yyyy-MM-dd', () {
      expect(formatApiDay(DateTime(2026, 3, 7)), '2026-03-07');
      expect(parseApiDay('2026-03-07'), DateTime(2026, 3, 7));
      // A time on the end is ignored rather than shifting the day.
      expect(parseApiDay('2026-03-07T00:00:00'), DateTime(2026, 3, 7));
      expect(() => parseApiDay('March'), throwsFormatException);
    });

    test('the request bodies match what the API expects', () {
      expect(const FarmInput(name: 'A', district: 'Kandy', area: 2.5).toJson(), {
        'name': 'A',
        'district': 'Kandy',
        'area': 2.5,
      });
      expect(const FieldInput(name: 'F', area: 1).toJson(), {'name': 'F', 'area': 1});
      expect(
        CropInput(
          cropType: 'Paddy',
          variety: '',
          plantingDate: DateTime(2026, 9),
          expectedHarvestDate: DateTime(2026, 12, 20),
          expectedQuantity: 300,
        ).toJson(),
        {
          'cropType': 'Paddy',
          'variety': '',
          'plantingDate': '2026-09-01',
          'expectedHarvestDate': '2026-12-20',
          'expectedQuantity': 300,
        },
      );
    });
  });

  group('the API classes', () {
    late FakeApi fake;
    late FarmsApi farms;
    late CropsApi crops;

    setUp(() {
      fake = FakeApi();
      final client = fakeApiClient(fake, readToken: () => 'token');
      farms = FarmsApi(client);
      crops = CropsApi(client);
    });

    test('farms reads the plain list', () async {
      fake.on('GET', '/api/farms', (_) => FakeResponse(200, [farmJson(), farmJson(id: 2)]));
      final list = await farms.farms();
      expect(list.map((farm) => farm.id), [1, 2]);
      expect(fake.lastTo('GET', '/api/farms')!.headers['Authorization'], 'Bearer token');
    });

    test('creating and editing a farm send the same body', () async {
      fake
        ..on('POST', '/api/farms', (_) => FakeResponse(201, farmJson(id: 5, name: 'New')))
        ..on('PUT', '/api/farms/5', (_) => FakeResponse(200, farmJson(id: 5, name: 'Renamed')));
      const input = FarmInput(name: 'New', district: 'Galle', area: 3);

      expect((await farms.createFarm(input)).id, 5);
      expect((await farms.updateFarm(5, input)).name, 'Renamed');
      expect(fake.lastTo('POST', '/api/farms')!.json, input.toJson());
      expect(fake.lastTo('PUT', '/api/farms/5')!.json, input.toJson());
    });

    test('deleting a farm that has crops surfaces the server message', () async {
      fake.on(
        'DELETE',
        '/api/farms/1',
        (_) => const FakeResponse(400, {
          'message': 'Cannot delete a farm that has crops planted. Remove crops first.',
        }),
      );
      await expectLater(
        farms.deleteFarm(1),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.badRequest)
              .having((e) => e.serverMessage, 'message', contains('Remove crops first')),
        ),
      );
    });

    test('deleting a farm succeeds on 204', () async {
      fake.on('DELETE', '/api/farms/1', (_) => const FakeResponse(204));
      await farms.deleteFarm(1);
      expect(fake.lastTo('DELETE', '/api/farms/1'), isNotNull);
    });

    test('fields are listed and added under their farm', () async {
      fake
        ..on('GET', '/api/farms/1/fields', (_) => FakeResponse(200, [fieldJson()]))
        ..on(
          'POST',
          '/api/farms/1/fields',
          (_) => FakeResponse(201, fieldJson(id: 11, name: 'South')),
        );

      expect((await farms.fields(1)).single.name, 'North Field');
      final added = await farms.addField(1, const FieldInput(name: 'South', area: 2));
      expect(added.id, 11);
      expect(fake.lastTo('POST', '/api/farms/1/fields')!.json, {'name': 'South', 'area': 2});
    });

    test('crops are listed by field and read by id', () async {
      fake
        ..on(
          'GET',
          '/api/fields/10/crops',
          (_) => FakeResponse(200, [cropJson(), cropJson(id: 101)]),
        )
        ..on('GET', '/api/crops/100', (_) => FakeResponse(200, cropJson()));

      expect((await crops.forField(10)).map((crop) => crop.id), [100, 101]);
      expect((await crops.byId(100)).cropType, 'Green Gram');
    });

    test('planting a crop sends days as yyyy-MM-dd', () async {
      fake.on('POST', '/api/fields/10/crops', (_) => FakeResponse(201, cropJson(id: 102)));

      final crop = await crops.plant(
        10,
        CropInput(
          cropType: 'Green Gram',
          variety: 'MI 5',
          plantingDate: DateTime(2026, 9),
          expectedHarvestDate: DateTime(2026, 11, 15),
          expectedQuantity: 250.5,
        ),
      );

      expect(crop.id, 102);
      expect(fake.lastTo('POST', '/api/fields/10/crops')!.json, {
        'cropType': 'Green Gram',
        'variety': 'MI 5',
        'plantingDate': '2026-09-01',
        'expectedHarvestDate': '2026-11-15',
        'expectedQuantity': 250.5,
      });
    });

    test('the status is the only thing sent when a crop is updated', () async {
      fake.on('PUT', '/api/crops/100', (_) => FakeResponse(200, cropJson(status: 'Harvested')));

      final crop = await crops.updateStatus(100, CropStatus.harvested);

      expect(crop.status, CropStatus.harvested);
      expect(fake.lastTo('PUT', '/api/crops/100')!.json, {'status': 'Harvested'});
    });

    test('the farmer’s crops and the crop types are read', () async {
      fake
        ..on('GET', '/api/crops/mine', (_) => FakeResponse(200, [farmerCropJson()]))
        ..on('GET', '/api/crop-types', (_) => const FakeResponse(200, ['Paddy', 'Green Gram']));

      expect((await crops.mine()).single.farmName, 'Green Acres');
      expect(await crops.cropTypes(), ['Paddy', 'Green Gram']);
    });
  });
}
