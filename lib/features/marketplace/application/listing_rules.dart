import '../data/harvest_listing.dart';

/// The browse screen's price range. The server filters by crop and district; the price is
/// filtered on the phone, as on the website.
class PriceRange {
  const PriceRange({this.min, this.max});

  /// Reads the two text fields. Blank or unreadable text means "no limit".
  factory PriceRange.parse(String min, String max) =>
      PriceRange(min: double.tryParse(min.trim()), max: double.tryParse(max.trim()));

  static const any = PriceRange();

  final double? min;
  final double? max;

  bool get isSet => min != null || max != null;

  /// Whether [pricePerUnit] is inside the range, both ends included.
  bool contains(double pricePerUnit) =>
      (min == null || pricePerUnit >= min!) && (max == null || pricePerUnit <= max!);

  List<HarvestListing> apply(List<HarvestListing> listings) => isSet
      ? [
          for (final listing in listings)
            if (contains(listing.pricePerUnit)) listing,
        ]
      : listings;
}

/// Whether the signed-in user is the farmer who made [listing]. [farmerProfileId] comes from
/// the current user's profile and is null for everyone who isn't a farmer.
bool isOwnListing(HarvestListing listing, int? farmerProfileId) =>
    farmerProfileId != null && listing.farmerProfileId == farmerProfileId;
