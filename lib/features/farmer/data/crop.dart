import '../../../core/api/json.dart';

/// Where a crop is in its season. The API sends the name as a string.
enum CropStatus {
  seeded('Seeded'),
  growing('Growing'),
  harvested('Harvested');

  const CropStatus(this.apiName);

  factory CropStatus.fromApi(Object? raw) {
    for (final status in values) {
      if (status.apiName == raw) {
        return status;
      }
    }
    throw FormatException('Unknown crop status: "$raw"');
  }

  final String apiName;
}

/// A calendar day from the API (a `DateOnly`, sent as `2026-09-01`), as a local date. A date
/// with no time isn't an instant, so it must not be shifted by a time zone.
DateTime parseApiDay(String value) {
  final day = value.length >= 10 ? value.substring(0, 10) : value;
  final parts = day.split('-');
  if (parts.length != 3) {
    throw FormatException('Expected a date like 2026-09-01, got "$value"');
  }
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

/// A calendar day as the API expects it: `2026-09-01`.
String formatApiDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// A crop planted in a field: the API's `CropDto`. [expectedQuantity] is in kilograms.
class Crop {
  const Crop({
    required this.id,
    required this.fieldId,
    required this.cropType,
    required this.variety,
    required this.plantingDate,
    required this.expectedHarvestDate,
    required this.expectedQuantity,
    required this.status,
  });

  factory Crop.fromJson(Json json) => Crop(
    id: (json['cropId'] as num).toInt(),
    fieldId: (json['fieldId'] as num).toInt(),
    cropType: field<String>(json, 'cropType'),
    variety: json['variety'] as String? ?? '',
    plantingDate: parseApiDay(field<String>(json, 'plantingDate')),
    expectedHarvestDate: parseApiDay(field<String>(json, 'expectedHarvestDate')),
    expectedQuantity: (json['expectedQuantity'] as num).toDouble(),
    status: CropStatus.fromApi(json['status']),
  );

  final int id;
  final int fieldId;
  final String cropType;
  final String variety;
  final DateTime plantingDate;
  final DateTime expectedHarvestDate;
  final double expectedQuantity;
  final CropStatus status;
}

/// One of the farmer's crops with the field and farm it is in: the API's `FarmerCropSummary`
/// (`GET /api/crops/mine`). It's what a crop picker needs, because "Paddy, North Field, Green
/// Acres" means more to a farmer than a crop number.
class FarmerCrop {
  const FarmerCrop({
    required this.id,
    required this.cropType,
    required this.variety,
    required this.status,
    required this.plantingDate,
    required this.expectedHarvestDate,
    required this.expectedQuantity,
    required this.fieldId,
    required this.fieldName,
    required this.farmId,
    required this.farmName,
    required this.district,
  });

  factory FarmerCrop.fromJson(Json json) => FarmerCrop(
    id: (json['cropId'] as num).toInt(),
    cropType: field<String>(json, 'cropType'),
    variety: json['variety'] as String? ?? '',
    status: CropStatus.fromApi(json['status']),
    plantingDate: parseApiDay(field<String>(json, 'plantingDate')),
    expectedHarvestDate: parseApiDay(field<String>(json, 'expectedHarvestDate')),
    expectedQuantity: (json['expectedQuantity'] as num).toDouble(),
    fieldId: (json['fieldId'] as num).toInt(),
    fieldName: json['fieldName'] as String? ?? '',
    farmId: (json['farmId'] as num).toInt(),
    farmName: json['farmName'] as String? ?? '',
    district: json['district'] as String? ?? '',
  );

  final int id;
  final String cropType;
  final String variety;
  final CropStatus status;
  final DateTime plantingDate;
  final DateTime expectedHarvestDate;
  final double expectedQuantity;
  final int fieldId;
  final String fieldName;
  final int farmId;
  final String farmName;
  final String district;
}

/// The body for planting a crop (`POST /api/fields/{id}/crops`). A new crop starts as
/// [CropStatus.seeded]; the server sets that.
class CropInput {
  const CropInput({
    required this.cropType,
    required this.variety,
    required this.plantingDate,
    required this.expectedHarvestDate,
    required this.expectedQuantity,
  });

  final String cropType;
  final String variety;
  final DateTime plantingDate;
  final DateTime expectedHarvestDate;
  final double expectedQuantity;

  Json toJson() => {
    'cropType': cropType,
    'variety': variety,
    'plantingDate': formatApiDay(plantingDate),
    'expectedHarvestDate': formatApiDay(expectedHarvestDate),
    'expectedQuantity': expectedQuantity,
  };
}
