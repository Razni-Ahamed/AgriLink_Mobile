import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import 'farm.dart';

/// `/api/farms`: the farmer's farms and their fields.
class FarmsApi {
  FarmsApi(this._api);

  final ApiClient _api;

  /// The signed-in farmer's farms, newest first. The API returns them all in one list.
  Future<List<Farm>> farms() => _api.get(
    '/api/farms',
    decode: (data) => [for (final item in asJsonList(data)) Farm.fromJson(item)],
  );

  Future<Farm> createFarm(FarmInput input) =>
      _api.post('/api/farms', body: input.toJson(), decode: (data) => Farm.fromJson(asJson(data)));

  Future<Farm> updateFarm(int farmId, FarmInput input) => _api.put(
    '/api/farms/$farmId',
    body: input.toJson(),
    decode: (data) => Farm.fromJson(asJson(data)),
  );

  /// Fails with a 400 and a message if any field has crops planted, since crops can't be removed.
  Future<void> deleteFarm(int farmId) =>
      _api.delete('/api/farms/$farmId', decode: ApiClient.ignoreBody);

  Future<List<FarmField>> fields(int farmId) => _api.get(
    '/api/farms/$farmId/fields',
    decode: (data) => [for (final item in asJsonList(data)) FarmField.fromJson(item)],
  );

  Future<FarmField> addField(int farmId, FieldInput input) => _api.post(
    '/api/farms/$farmId/fields',
    body: input.toJson(),
    decode: (data) => FarmField.fromJson(asJson(data)),
  );
}

final farmsApiProvider = Provider<FarmsApi>((ref) => FarmsApi(ref.watch(apiClientProvider)));
