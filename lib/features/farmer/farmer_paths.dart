import '../../app/router/app_routes.dart';

/// The paths of the farmer's pages. The farm pages match the website's: a farm is `/farms/12`,
/// its field `/farms/12/fields/3` and a crop in that field `/farms/12/fields/3/crops/40`.
abstract final class FarmerPaths {
  static String farm(int farmId) => '${AppRoutes.farms}/$farmId';

  static String field(int farmId, int fieldId) => '${farm(farmId)}/fields/$fieldId';

  static String crop(int farmId, int fieldId, int cropId) =>
      '${field(farmId, fieldId)}/crops/$cropId';

  /// Reporting a problem, optionally already choosing [cropId] (from a crop's page).
  static String newIssue({int? cropId}) =>
      '${AppRoutes.myIssues}/new${cropId == null ? '' : '?cropId=$cropId'}';

  /// One of the farmer's issues, under "My Issues".
  static String issue(int issueId) => '${AppRoutes.myIssues}/$issueId';

  /// An advisory, at the website's path. Open it with `context.push` so Back returns to where
  /// the farmer came from.
  static String advisory(int advisoryId) => '/advisories/$advisoryId';

  /// The advisory route's pattern, for the router.
  static const advisoryPattern = '/advisories/:advisoryId';
}
