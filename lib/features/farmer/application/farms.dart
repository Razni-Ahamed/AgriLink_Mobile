import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../data/crop.dart';
import '../data/crops_api.dart';
import '../data/farm.dart';
import '../data/farms_api.dart';

// Every provider that holds the signed-in farmer's data watches the session, so it is thrown
// away on sign-out and the next person on the phone never sees it.

/// The farmer's farms, newest first.
final myFarmsProvider = FutureProvider.autoDispose<List<Farm>>((ref) {
  ref.watch(sessionTokenProvider);
  return ref.watch(farmsApiProvider).farms();
});

/// One farm, or null if the farmer has no farm with this id. The API has no "farm by id", so
/// this picks it out of the list, as the website does.
final farmProvider = FutureProvider.autoDispose.family<Farm?, int>((ref, farmId) async {
  final farms = await ref.watch(myFarmsProvider.future);
  for (final farm in farms) {
    if (farm.id == farmId) {
      return farm;
    }
  }
  return null;
});

/// The fields of one farm.
final farmFieldsProvider = FutureProvider.autoDispose.family<List<FarmField>, int>((ref, farmId) {
  ref.watch(sessionTokenProvider);
  return ref.watch(farmsApiProvider).fields(farmId);
});

/// Identifies one field: a field's id is only meaningful together with its farm.
typedef FieldKey = ({int farmId, int fieldId});

/// One field, or null if the farm has no such field. Picked out of the farm's fields, since the
/// API has no "field by id" either.
final fieldProvider = FutureProvider.autoDispose.family<FarmField?, FieldKey>((ref, key) async {
  final fields = await ref.watch(farmFieldsProvider(key.farmId).future);
  for (final field in fields) {
    if (field.id == key.fieldId) {
      return field;
    }
  }
  return null;
});

/// The crops planted in one field, newest first.
final fieldCropsProvider = FutureProvider.autoDispose.family<List<Crop>, int>((ref, fieldId) {
  ref.watch(sessionTokenProvider);
  return ref.watch(cropsApiProvider).forField(fieldId);
});

/// One crop.
final cropProvider = FutureProvider.autoDispose.family<Crop, int>((ref, cropId) {
  ref.watch(sessionTokenProvider);
  return ref.watch(cropsApiProvider).byId(cropId);
});

/// Every crop the farmer has, with its field and farm. For choosing a crop to report an issue on.
final myCropsProvider = FutureProvider.autoDispose<List<FarmerCrop>>((ref) {
  ref.watch(sessionTokenProvider);
  return ref.watch(cropsApiProvider).mine();
});

/// The crop names the API accepts. The same for everyone, so it isn't tied to the session.
final cropTypesProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(cropsApiProvider).cropTypes(),
);
