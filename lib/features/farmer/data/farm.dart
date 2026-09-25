import '../../../core/api/json.dart';

/// A farm: the API's `FarmDto`. [area] is in acres.
class Farm {
  const Farm({
    required this.id,
    required this.name,
    required this.district,
    required this.area,
    required this.createdAt,
  });

  factory Farm.fromJson(Json json) => Farm(
    id: (json['farmId'] as num).toInt(),
    name: field<String>(json, 'name'),
    district: json['district'] as String? ?? '',
    area: (json['area'] as num).toDouble(),
    createdAt: parseApiDate(field<String>(json, 'createdAt')),
  );

  final int id;
  final String name;
  final String district;
  final double area;
  final DateTime createdAt;
}

/// A field on a farm: the API's `FieldDto`. [area] is in acres.
///
/// Named `FarmField` so it doesn't read like a form field. The API can add fields but not edit
/// or delete them.
class FarmField {
  const FarmField({required this.id, required this.farmId, required this.name, required this.area});

  factory FarmField.fromJson(Json json) => FarmField(
    id: (json['fieldId'] as num).toInt(),
    farmId: (json['farmId'] as num).toInt(),
    name: field<String>(json, 'name'),
    area: (json['area'] as num).toDouble(),
  );

  final int id;
  final int farmId;
  final String name;
  final double area;
}

/// The body for creating a farm (`POST /api/farms`) or editing one (`PUT /api/farms/{id}`): the
/// two take the same fields.
class FarmInput {
  const FarmInput({required this.name, required this.district, required this.area});

  final String name;
  final String district;
  final double area;

  Json toJson() => {'name': name, 'district': district, 'area': area};
}

/// The body for adding a field to a farm (`POST /api/farms/{id}/fields`).
class FieldInput {
  const FieldInput({required this.name, required this.area});

  final String name;
  final double area;

  Json toJson() => {'name': name, 'area': area};
}
