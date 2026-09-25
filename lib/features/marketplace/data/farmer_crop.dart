import '../../../core/api/json.dart';

/// One of the farmer's crops, as `GET /api/crops/mine` returns it, for choosing what to list.
///
/// Farms and crops belong to the farmer feature; this keeps only what the listing form needs,
/// so the marketplace doesn't depend on that feature's models.
class FarmerCrop {
  const FarmerCrop({
    required this.id,
    required this.cropType,
    required this.variety,
    required this.fieldName,
    required this.farmName,
  });

  factory FarmerCrop.fromJson(Json json) => FarmerCrop(
    id: (json['cropId'] as num).toInt(),
    cropType: json['cropType'] as String? ?? '',
    variety: json['variety'] as String? ?? '',
    fieldName: json['fieldName'] as String? ?? '',
    farmName: json['farmName'] as String? ?? '',
  );

  final int id;
  final String cropType;
  final String variety;
  final String fieldName;
  final String farmName;
}
