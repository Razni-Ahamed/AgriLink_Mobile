import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import 'crop.dart';

/// Crops, and the list of crop types they can be.
class CropsApi {
  CropsApi(this._api);

  final ApiClient _api;

  /// The crops planted in one field, newest first.
  Future<List<Crop>> forField(int fieldId) => _api.get(
    '/api/fields/$fieldId/crops',
    decode: (data) => [for (final item in asJsonList(data)) Crop.fromJson(item)],
  );

  Future<Crop> byId(int cropId) =>
      _api.get('/api/crops/$cropId', decode: (data) => Crop.fromJson(asJson(data)));

  Future<Crop> plant(int fieldId, CropInput input) => _api.post(
    '/api/fields/$fieldId/crops',
    body: input.toJson(),
    decode: (data) => Crop.fromJson(asJson(data)),
  );

  /// The only thing about a crop that can change once planted.
  Future<Crop> updateStatus(int cropId, CropStatus status) => _api.put(
    '/api/crops/$cropId',
    body: {'status': status.apiName},
    decode: (data) => Crop.fromJson(asJson(data)),
  );

  /// Every crop the signed-in farmer has, with its field and farm. For the crop pickers.
  Future<List<FarmerCrop>> mine() => _api.get(
    '/api/crops/mine',
    decode: (data) => [for (final item in asJsonList(data)) FarmerCrop.fromJson(item)],
  );

  /// The crop names the API accepts ("Green Gram"). Anything else is refused.
  Future<List<String>> cropTypes() => _api.get(
    '/api/crop-types',
    decode: (data) => [for (final item in data! as List<Object?>) item! as String],
  );
}

final cropsApiProvider = Provider<CropsApi>((ref) => CropsApi(ref.watch(apiClientProvider)));
