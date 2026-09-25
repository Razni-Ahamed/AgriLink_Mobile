import '../../../core/api/json.dart';
import 'marketplace_enums.dart';

/// A buyer's offer to buy part of a listing: the API's `PurchaseRequestResponse`.
///
/// It carries no phone number or email: a request isn't a deal yet, so the buyer's contact
/// details stay hidden until the farmer accepts and an order exists.
class PurchaseRequest {
  const PurchaseRequest({
    required this.id,
    required this.harvestId,
    required this.buyerProfileId,
    required this.requestedQuantity,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.cropType,
    required this.district,
    required this.pricePerUnit,
    required this.buyerName,
    required this.buyerBusinessName,
  });

  factory PurchaseRequest.fromJson(Json json) => PurchaseRequest(
    id: (json['requestId'] as num).toInt(),
    harvestId: (json['harvestId'] as num).toInt(),
    buyerProfileId: (json['buyerProfileId'] as num).toInt(),
    requestedQuantity: (json['requestedQuantity'] as num).toDouble(),
    message: json['message'] as String? ?? '',
    status: PurchaseRequestStatus.fromApi(json['status']),
    createdAt: parseApiDate(field<String>(json, 'createdAt')),
    cropType: json['cropType'] as String? ?? '',
    district: json['district'] as String? ?? '',
    pricePerUnit: (json['pricePerUnit'] as num).toDouble(),
    buyerName: json['buyerName'] as String? ?? '',
    buyerBusinessName: json['buyerBusinessName'] as String? ?? '',
  );

  final int id;
  final int harvestId;
  final int buyerProfileId;
  final double requestedQuantity;

  /// The buyer's note to the farmer; empty when they didn't write one.
  final String message;
  final PurchaseRequestStatus status;
  final DateTime createdAt;
  final String cropType;
  final String district;
  final double pricePerUnit;
  final String buyerName;
  final String buyerBusinessName;

  /// What the buyer would pay at the listing's current price.
  double get total => requestedQuantity * pricePerUnit;
}

/// The body for asking to buy: `POST /api/purchase-requests`.
class CreatePurchaseRequestRequest {
  const CreatePurchaseRequestRequest({
    required this.harvestId,
    required this.requestedQuantity,
    this.message,
  });

  final int harvestId;
  final double requestedQuantity;
  final String? message;

  Json toJson() => {
    'harvestId': harvestId,
    'requestedQuantity': requestedQuantity,
    if (message != null && message!.trim().isNotEmpty) 'message': message!.trim(),
  };
}
