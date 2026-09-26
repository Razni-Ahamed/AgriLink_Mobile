import '../../../core/api/json.dart';
import 'marketplace_enums.dart';

/// A harvest a farmer has put up for sale: the API's `HarvestListingResponse`.
///
/// Quantities are in kilograms and [pricePerUnit] is rupees per kilogram, as on the website.
class HarvestListing {
  const HarvestListing({
    required this.id,
    required this.farmerProfileId,
    required this.cropId,
    required this.cropType,
    required this.variety,
    required this.quantity,
    required this.availableQuantity,
    required this.harvestDate,
    required this.pricePerUnit,
    required this.location,
    required this.district,
    required this.status,
    required this.createdAt,
  });

  factory HarvestListing.fromJson(Json json) => HarvestListing(
    id: (json['harvestId'] as num).toInt(),
    farmerProfileId: (json['farmerProfileId'] as num).toInt(),
    cropId: (json['cropId'] as num).toInt(),
    cropType: json['cropType'] as String? ?? '',
    variety: json['variety'] as String? ?? '',
    quantity: (json['quantity'] as num).toDouble(),
    availableQuantity: (json['availableQuantity'] as num).toDouble(),
    harvestDate: parseApiDate(field<String>(json, 'harvestDate')),
    pricePerUnit: (json['pricePerUnit'] as num).toDouble(),
    location: json['location'] as String? ?? '',
    district: json['district'] as String? ?? '',
    status: HarvestStatus.fromApi(json['status']),
    createdAt: parseApiDate(field<String>(json, 'createdAt')),
  );

  final int id;
  final int farmerProfileId;
  final int cropId;
  final String cropType;
  final String variety;

  /// What the farmer first listed.
  final double quantity;

  /// What is still for sale: [quantity] minus accepted requests.
  final double availableQuantity;
  final DateTime harvestDate;
  final double pricePerUnit;
  final String location;
  final String district;
  final HarvestStatus status;
  final DateTime createdAt;

  /// A cancelled listing can be reopened only while it still has something left to sell.
  bool get canReopen => status == HarvestStatus.cancelled && availableQuantity > 0;
}

/// The body for listing a harvest: `POST /api/harvests`. [cropId] must be one of the farmer's
/// own crops.
class CreateHarvestListingRequest {
  const CreateHarvestListingRequest({
    required this.cropId,
    required this.quantity,
    required this.harvestDate,
    required this.pricePerUnit,
    required this.location,
  });

  final int cropId;
  final double quantity;
  final DateTime harvestDate;
  final double pricePerUnit;
  final String location;

  Json toJson() => {
    'cropId': cropId,
    'quantity': quantity,
    'harvestDate': apiDateOnly(harvestDate),
    'pricePerUnit': pricePerUnit,
    'location': location,
  };
}

/// The body for changing a listing: `PUT /api/harvests/{id}`. Only the fields that are set are
/// sent, so a status change alone leaves the price and the rest as they are.
class UpdateHarvestListingRequest {
  const UpdateHarvestListingRequest({
    this.status,
    this.pricePerUnit,
    this.location,
    this.harvestDate,
  });

  final HarvestStatus? status;
  final double? pricePerUnit;
  final String? location;
  final DateTime? harvestDate;

  Json toJson() => {
    if (status != null) 'status': status!.apiName,
    if (pricePerUnit != null) 'pricePerUnit': pricePerUnit,
    if (location != null) 'location': location,
    if (harvestDate != null) 'harvestDate': apiDateOnly(harvestDate!),
  };
}

/// A calendar date as the API's `DateOnly` expects it: `2026-09-25`, with no time or time zone,
/// so the day the farmer picked never shifts.
String apiDateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
