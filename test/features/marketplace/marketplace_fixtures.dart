import 'package:agrilink_mobile/core/api/json.dart';

/// API response bodies for the marketplace tests. Each takes overrides for the fields a test
/// cares about.

Json listingJson({
  int id = 7,
  int farmerProfileId = 11,
  String cropType = 'Paddy',
  String variety = 'Samba',
  num quantity = 500,
  num availableQuantity = 400,
  num pricePerUnit = 120,
  String status = 'Active',
  String district = 'Kurunegala',
  String location = 'Wariyapola',
}) => {
  'harvestId': id,
  'farmerProfileId': farmerProfileId,
  'cropId': 3,
  'cropType': cropType,
  'variety': variety,
  'quantity': quantity,
  'availableQuantity': availableQuantity,
  'harvestDate': '2026-09-20',
  'pricePerUnit': pricePerUnit,
  'location': location,
  'district': district,
  'status': status,
  'createdAt': '2026-09-21T08:30:00Z',
};

Json requestJson({
  int id = 21,
  int harvestId = 7,
  num requestedQuantity = 50,
  num pricePerUnit = 120,
  String status = 'Pending',
  String message = 'Can you deliver to Kandy?',
}) => {
  'requestId': id,
  'harvestId': harvestId,
  'buyerProfileId': 31,
  'requestedQuantity': requestedQuantity,
  'message': message,
  'status': status,
  'createdAt': '2026-09-22T10:00:00Z',
  'cropType': 'Paddy',
  'district': 'Kurunegala',
  'pricePerUnit': pricePerUnit,
  'buyerName': 'Nimal Silva',
  'buyerBusinessName': 'Silva Traders',
};

Json orderJson({
  int id = 41,
  String status = 'Confirmed',
  String orderDate = '2026-09-23T09:00:00Z',
  String? buyerPhone = '0771234567',
}) => {
  'orderId': id,
  'requestId': 21,
  'farmerProfileId': 11,
  'buyerProfileId': 31,
  'totalQuantity': 50,
  'totalAmount': 6000,
  'status': status,
  'orderDate': orderDate,
  'completedAt': status == 'Confirmed' ? null : '2026-09-24T09:00:00Z',
  'farmerName': 'Sunil Perera',
  'farmerPhone': '0712345678',
  'farmerEmail': 'farmer@example.test',
  'farmerDistrict': 'Kurunegala',
  'farmerPhotoUrl': null,
  'buyerName': 'Nimal Silva',
  'buyerBusinessName': 'Silva Traders',
  'buyerPhone': buyerPhone,
  'buyerEmail': 'buyer@example.test',
  'buyerDistrict': 'Kandy',
  'buyerPhotoUrl': '',
  'cropType': 'Paddy',
  'pricePerUnit': 120,
  'harvestLocation': 'Wariyapola',
};

Json cropJson({int id = 3, String cropType = 'Paddy'}) => {
  'cropId': id,
  'cropType': cropType,
  'variety': 'Samba',
  'status': 'Growing',
  'plantingDate': '2026-05-01',
  'expectedHarvestDate': '2026-09-15',
  'expectedQuantity': 600,
  'fieldId': 2,
  'fieldName': 'North Field',
  'farmId': 1,
  'farmName': 'Green Acres',
  'district': 'Kurunegala',
};
