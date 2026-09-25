import '../../../core/api/api_error_parser.dart';
import '../../../l10n/l10n.dart';

/// The marketplace DTOs' field names (as ASP.NET reports validation errors) → the form fields
/// that show them.
const marketplaceServerFieldNames = {
  'CropId': 'cropId',
  'Quantity': 'quantity',
  'RequestedQuantity': 'requestedQuantity',
  'HarvestDate': 'harvestDate',
  'PricePerUnit': 'pricePerUnit',
  'Location': 'location',
  'Message': 'message',
};

/// [parseApiError] for the marketplace's forms. The server's own rule messages ("Requested
/// quantity exceeds available quantity.") come through as they are, like on the website.
ParsedApiError parseMarketplaceError(Object error, AppLocalizations l10n, MessageOf generic) =>
    parseApiError(
      error,
      l10n,
      generic: generic,
      conflict: generic,
      serverFieldNames: marketplaceServerFieldNames,
    );

/// A positive number typed into a field, or null. Accepts "1,250.5" as typed with a separator.
double? parsePositiveNumber(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', ''));
  return value != null && value > 0 ? value : null;
}

/// [value] for an editable text field: "120" rather than "120.0", and no grouping separators.
String plainNumber(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();
