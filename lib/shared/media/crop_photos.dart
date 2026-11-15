/// One photograph per crop type, the same ones the website uses, so every listing, crop card and
/// crop page has a real picture of what is being grown or sold.
///
/// All are free under the Unsplash licence, which requires no credit; the photographers are kept
/// in the website's `frontend/src/lib/cropPhotos.ts` as a record. 800 × 600 WebP, about 100 KB
/// each, in `assets/photos/crops/`.
library;

/// Crop names with a photo of their own, as file names (`Green Gram` → `green-gram`).
const Set<String> _cropsWithPhotos = {
  'avocado', 'banana', 'beans', 'beetroot', 'brinjal', 'cabbage', 'cardamom', 'carrot', //
  'cassava', 'chilli', 'cinnamon', 'coconut', 'cowpea', 'cucumber', 'green-gram', 'groundnut',
  'leeks', 'maize', 'mango', 'okra', 'onion', 'paddy', 'papaya', 'passion-fruit', 'pepper',
  'pineapple', 'potato', 'pumpkin', 'rubber', 'soybean', 'sugarcane', 'sweet-potato', 'tea',
  'tomato',
};

/// `Green Gram` → `green-gram`.
String cropPhotoSlug(String cropType) =>
    cropType.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');

/// The asset path of a crop's photo, or the general market photo for a crop with none of its own.
String cropPhotoAsset(String cropType) {
  final slug = cropPhotoSlug(cropType);
  return 'assets/photos/crops/${_cropsWithPhotos.contains(slug) ? slug : 'other'}.webp';
}

/// The Sri Lankan field and market photos, named by what each page is about.
abstract final class Scenes {
  static const String fields = 'assets/photos/scenes/paddy-aerial.webp';
  static const String farm = 'assets/photos/scenes/farmer-garden.webp';
  static const String morning = 'assets/photos/scenes/tea-haputale.webp';
  static const String market = 'assets/photos/scenes/vegetable-stall.webp';
  static const String produce = 'assets/photos/scenes/fruit-stall.webp';
  static const String handover = 'assets/photos/scenes/market-handover.webp';
  static const String inspection = 'assets/photos/scenes/examining-leaves.webp';
  static const String care = 'assets/photos/scenes/tending-crop.webp';
  static const String people = 'assets/photos/scenes/paddy-farmer.webp';
  static const String harvestWork = 'assets/photos/scenes/rice-winnowing.webp';
  static const String path = 'assets/photos/scenes/walking-fields.webp';

  static const List<String> _farms = [farm, fields, morning, care];

  /// Farms have no photos of their own: each gets one of the field photos, picked by its id so a
  /// farm always shows the same one (as on the website).
  static String forFarm(int farmId) => _farms[farmId.abs() % _farms.length];
}
