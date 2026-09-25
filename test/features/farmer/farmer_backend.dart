import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';
import 'farmer_fixtures.dart';

/// A pretend farmer API that remembers what the app does: create a farm and it shows up in the
/// list, delete one and it is gone. Ids are fixed ranges so each path can be registered:
/// farms 1 to 9, fields 10 to 19, crops 100 to 109.
class FarmerBackend {
  FarmerBackend(
    this.api, {
    List<Map<String, Object?>>? farms,
    List<Map<String, Object?>>? fields,
    List<Map<String, Object?>>? crops,
  }) : farms = farms ?? [farmJson()],
       fields = fields ?? [fieldJson()],
       crops = crops ?? [cropJson()] {
    api
      ..on('GET', '/api/users/me', (_) => FakeResponse(200, profileJson(Role.farmer)))
      ..on('GET', '/api/districts', (_) => const FakeResponse(200, ['Kandy', 'Galle', 'Colombo']))
      ..on(
        'GET',
        '/api/crop-types',
        (_) => const FakeResponse(200, ['Paddy', 'Green Gram', 'Tomato']),
      )
      ..on('GET', '/api/farms', (_) => FakeResponse(200, this.farms))
      ..on('POST', '/api/farms', (request) {
        final body = request.json;
        final farm = farmJson(
          id: _nextFarm++,
          name: body['name']! as String,
          district: body['district']! as String,
          area: body['area']! as num,
        );
        this.farms.insert(0, farm);
        return FakeResponse(201, farm);
      });

    for (var id = 1; id <= 9; id++) {
      api
        ..on('PUT', '/api/farms/$id', (request) {
          final body = request.json;
          final index = this.farms.indexWhere((farm) => farm['farmId'] == id);
          this.farms[index] = farmJson(
            id: id,
            name: body['name']! as String,
            district: body['district']! as String,
            area: body['area']! as num,
          );
          return FakeResponse(200, this.farms[index]);
        })
        ..on('DELETE', '/api/farms/$id', (_) {
          this.farms.removeWhere((farm) => farm['farmId'] == id);
          return const FakeResponse(204);
        })
        ..on(
          'GET',
          '/api/farms/$id/fields',
          (_) => FakeResponse(200, [
            for (final field in this.fields)
              if (field['farmId'] == id) field,
          ]),
        )
        ..on('POST', '/api/farms/$id/fields', (request) {
          final body = request.json;
          final field = fieldJson(
            id: _nextField++,
            farmId: id,
            name: body['name']! as String,
            area: body['area']! as num,
          );
          this.fields.add(field);
          return FakeResponse(201, field);
        });
    }

    for (var id = 10; id <= 19; id++) {
      api
        ..on(
          'GET',
          '/api/fields/$id/crops',
          (_) => FakeResponse(200, [
            for (final crop in this.crops)
              if (crop['fieldId'] == id) crop,
          ]),
        )
        ..on('POST', '/api/fields/$id/crops', (request) {
          final body = request.json;
          final crop = cropJson(
            id: _nextCrop++,
            fieldId: id,
            cropType: body['cropType']! as String,
            variety: body['variety']! as String,
            plantingDate: body['plantingDate']! as String,
            expectedHarvestDate: body['expectedHarvestDate']! as String,
            expectedQuantity: body['expectedQuantity']! as num,
          );
          this.crops.add(crop);
          return FakeResponse(201, crop);
        });
    }

    for (var id = 100; id <= 109; id++) {
      api
        ..on('GET', '/api/crops/$id', (_) => FakeResponse(200, _crop(id)))
        ..on('PUT', '/api/crops/$id', (request) {
          final index = this.crops.indexWhere((crop) => crop['cropId'] == id);
          this.crops[index] = {...this.crops[index], 'status': request.json['status']};
          return FakeResponse(200, this.crops[index]);
        });
    }
  }

  final FakeApi api;
  final List<Map<String, Object?>> farms;
  final List<Map<String, Object?>> fields;
  final List<Map<String, Object?>> crops;

  int _nextFarm = 2;
  int _nextField = 11;
  int _nextCrop = 101;

  Map<String, Object?> _crop(int id) => crops.firstWhere((crop) => crop['cropId'] == id);
}

/// Starts the app signed in as a farmer, who lands on the farms list.
Future<TestApp> pumpFarmer(
  WidgetTester tester,
  FarmerBackend backend, {
  String language = 'en',
  Size screen = const Size(390, 844),
}) => pumpAgriLink(
  tester,
  api: backend.api,
  session: Session(token: fakeJwt(), role: Role.farmer),
  language: language,
  screen: screen,
);
