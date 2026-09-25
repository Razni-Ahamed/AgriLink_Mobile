/// The limits the API enforces on farms, fields and crops (the DTO attributes in the backend),
/// checked on the phone first so a mistake doesn't cost a round trip.
abstract final class FarmLimits {
  /// Farm, field and variety names.
  static const int nameMaxLength = 100;

  /// Areas are in acres, between 0.01 and 100,000.
  static const double areaMin = 0.01;
  static const double areaMax = 100000;

  /// The expected harvest is in kilograms, between 0.01 and 1,000,000.
  static const double quantityMin = 0.01;
  static const double quantityMax = 1000000;
}

/// Reads a number the user typed: "12.5", or "12,5" from a keyboard that offers a comma. Null if
/// it isn't a number.
double? parseDecimal(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  return value != null && value.isFinite ? value : null;
}

/// A number to put back into a text field: 12 rather than 12.0.
String plainNumber(double value) =>
    value == value.truncateToDouble() ? value.toInt().toString() : value.toString();
