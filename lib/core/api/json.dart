/// A decoded JSON object. Models take one in `fromJson` and return one from `toJson`.
typedef Json = Map<String, dynamic>;

/// [value] as a JSON object, or a [FormatException] naming what was expected.
Json asJson(Object? value, [String what = 'response']) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  throw FormatException(
    'Expected a JSON object for $what, got ${value.runtimeType}',
  );
}

/// [value] as a list of JSON objects.
List<Json> asJsonList(Object? value, [String what = 'response']) {
  if (value is! List) {
    throw FormatException(
      'Expected a JSON list for $what, got ${value.runtimeType}',
    );
  }
  return [for (final item in value) asJson(item, what)];
}

/// Parses an API date-time. The API's times are UTC; one sent without an offset is read as
/// UTC too, rather than as the phone's local time. Convert with `.toLocal()` for display.
DateTime parseApiDate(String value) {
  final hasOffset = RegExp(r'(Z|[+-]\d\d:?\d\d)$').hasMatch(value);
  final hasTime = value.contains('T');
  return DateTime.parse(hasTime && !hasOffset ? '${value}Z' : value);
}

DateTime? parseApiDateOrNull(Object? value) =>
    value is String && value.isNotEmpty ? parseApiDate(value) : null;

/// Reads a field that must be present, with a clear error when the API shape changes.
T field<T>(Json json, String key) {
  final value = json[key];
  if (value is T) {
    return value;
  }
  throw FormatException('Expected "$key" to be $T, got ${value.runtimeType}');
}
