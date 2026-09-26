/// The API sends these as plain strings (`"Active"`). Each enum keeps that string in [apiName],
/// which is also what `statusLabel` and `StatusBadge.status` take.
///
/// An unknown value is a [FormatException]: it means the API changed, and a clear error is
/// better than quietly showing the wrong status.
T _parse<T extends Enum>(
  Object? raw,
  List<T> values,
  String Function(T value) nameOf,
  String what,
) {
  for (final value in values) {
    if (nameOf(value) == raw) {
      return value;
    }
  }
  throw FormatException('Unknown $what: "$raw"');
}

/// Where a harvest listing is. Only [active] listings show on the public marketplace.
enum HarvestStatus {
  active('Active'),
  sold('Sold'),
  cancelled('Cancelled');

  const HarvestStatus(this.apiName);

  factory HarvestStatus.fromApi(Object? raw) =>
      _parse(raw, values, (value) => value.apiName, 'harvest status');

  final String apiName;
}

/// Where a buyer's purchase request is. The server may cancel an old pending request by itself,
/// so a request can become [cancelled] without anyone pressing a button.
enum PurchaseRequestStatus {
  pending('Pending'),
  accepted('Accepted'),
  declined('Declined'),
  cancelled('Cancelled');

  const PurchaseRequestStatus(this.apiName);

  factory PurchaseRequestStatus.fromApi(Object? raw) =>
      _parse(raw, values, (value) => value.apiName, 'purchase request status');

  final String apiName;
}

/// The farmer's answer to a purchase request: `POST /api/purchase-requests/{id}/respond`.
enum RequestAction {
  accept('accept'),
  decline('decline');

  const RequestAction(this.apiName);

  final String apiName;
}

/// Where an order is. Either party can complete or cancel it, but only while it is [confirmed].
enum OrderStatus {
  confirmed('Confirmed'),
  completed('Completed'),
  cancelled('Cancelled');

  const OrderStatus(this.apiName);

  factory OrderStatus.fromApi(Object? raw) =>
      _parse(raw, values, (value) => value.apiName, 'order status');

  final String apiName;

  /// Completing and cancelling are only allowed while the order is still open.
  bool get canChange => this == confirmed;
}
