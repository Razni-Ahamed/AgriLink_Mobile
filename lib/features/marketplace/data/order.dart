import '../../../core/api/json.dart';
import 'marketplace_enums.dart';

/// A deal between a farmer and a buyer, made when the farmer accepts a purchase request: the
/// API's `OrderResponse`. It carries both parties' contact details so they can arrange delivery.
class Order {
  const Order({
    required this.id,
    required this.requestId,
    required this.totalQuantity,
    required this.totalAmount,
    required this.status,
    required this.orderDate,
    required this.farmer,
    required this.buyer,
    required this.cropType,
    required this.pricePerUnit,
    required this.harvestLocation,
    this.completedAt,
  });

  factory Order.fromJson(Json json) => Order(
    id: (json['orderId'] as num).toInt(),
    requestId: (json['requestId'] as num).toInt(),
    totalQuantity: (json['totalQuantity'] as num).toDouble(),
    totalAmount: (json['totalAmount'] as num).toDouble(),
    status: OrderStatus.fromApi(json['status']),
    orderDate: parseApiDate(field<String>(json, 'orderDate')),
    completedAt: parseApiDateOrNull(json['completedAt']),
    farmer: OrderParty(
      name: json['farmerName'] as String? ?? '',
      phone: _blankToNull(json['farmerPhone']),
      email: _blankToNull(json['farmerEmail']),
      district: json['farmerDistrict'] as String? ?? '',
      photoUrl: _blankToNull(json['farmerPhotoUrl']),
    ),
    buyer: OrderParty(
      name: json['buyerName'] as String? ?? '',
      businessName: _blankToNull(json['buyerBusinessName']),
      phone: _blankToNull(json['buyerPhone']),
      email: _blankToNull(json['buyerEmail']),
      district: json['buyerDistrict'] as String? ?? '',
      photoUrl: _blankToNull(json['buyerPhotoUrl']),
    ),
    cropType: json['cropType'] as String? ?? '',
    pricePerUnit: (json['pricePerUnit'] as num).toDouble(),
    harvestLocation: json['harvestLocation'] as String? ?? '',
  );

  final int id;
  final int requestId;
  final double totalQuantity;
  final double totalAmount;
  final OrderStatus status;
  final DateTime orderDate;

  /// When it was completed or cancelled; null while it is still confirmed.
  final DateTime? completedAt;
  final OrderParty farmer;
  final OrderParty buyer;
  final String cropType;
  final double pricePerUnit;
  final String harvestLocation;

  /// The person on the other side of the deal: the buyer for a farmer, the farmer for a buyer.
  OrderParty otherParty({required bool viewerIsFarmer}) => viewerIsFarmer ? buyer : farmer;
}

/// One side of an order, with what's needed to get in touch.
class OrderParty {
  const OrderParty({
    required this.name,
    required this.district,
    this.businessName,
    this.phone,
    this.email,
    this.photoUrl,
  });

  final String name;

  /// Only buyers have one.
  final String? businessName;

  /// Null when none is on file (e.g. a buyer an admin created without a phone number).
  final String? phone;
  final String? email;
  final String district;

  /// A public https address; null means the role's default picture.
  final String? photoUrl;

  /// The name to show first: a buyer's business, otherwise the person.
  String get displayName => businessName ?? name;
}

String? _blankToNull(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
