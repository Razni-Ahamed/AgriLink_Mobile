import '../../app/router/app_routes.dart';

/// The paths of the farmer's pages. They match the website's, so a farm is `/farms/12`, its field
/// `/farms/12/fields/3` and a crop in that field `/farms/12/fields/3/crops/40`.
abstract final class FarmerPaths {
  static String farm(int farmId) => '${AppRoutes.farms}/$farmId';

  static String field(int farmId, int fieldId) => '${farm(farmId)}/fields/$fieldId';

  static String crop(int farmId, int fieldId, int cropId) =>
      '${field(farmId, fieldId)}/crops/$cropId';
}
