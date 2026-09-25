/// JSON the API returns for farms, fields and crops, for tests.
Map<String, Object?> farmJson({
  int id = 1,
  String name = 'Green Acres',
  String district = 'Kandy',
  num area = 12.5,
}) => {
  'farmId': id,
  'name': name,
  'district': district,
  'area': area,
  'createdAt': '2026-08-01T06:00:00',
};

Map<String, Object?> fieldJson({
  int id = 10,
  int farmId = 1,
  String name = 'North Field',
  num area = 4,
}) => {'fieldId': id, 'farmId': farmId, 'name': name, 'area': area};

Map<String, Object?> cropJson({
  int id = 100,
  int fieldId = 10,
  String cropType = 'Green Gram',
  String variety = 'MI 5',
  String status = 'Seeded',
  String plantingDate = '2026-09-01',
  String expectedHarvestDate = '2026-11-15',
  num expectedQuantity = 250,
}) => {
  'cropId': id,
  'fieldId': fieldId,
  'cropType': cropType,
  'variety': variety,
  'plantingDate': plantingDate,
  'expectedHarvestDate': expectedHarvestDate,
  'expectedQuantity': expectedQuantity,
  'status': status,
};

Map<String, Object?> farmerCropJson({int id = 100, String cropType = 'Green Gram'}) => {
  'cropId': id,
  'cropType': cropType,
  'variety': 'MI 5',
  'status': 'Growing',
  'plantingDate': '2026-09-01',
  'expectedHarvestDate': '2026-11-15',
  'expectedQuantity': 250,
  'fieldId': 10,
  'fieldName': 'North Field',
  'farmId': 1,
  'farmName': 'Green Acres',
  'district': 'Kandy',
};
