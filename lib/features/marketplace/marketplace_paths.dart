/// The marketplace's pages that aren't sections of their own. They use the website's paths
/// (`/marketplace/12`, `/orders/41`) and are opened with `context.push`, so the back button
/// returns to whichever list the user came from.
abstract final class MarketplacePaths {
  static const listingPattern = '/marketplace/:harvestId';
  static const orderPattern = '/orders/:orderId';

  static String listing(int id) => '/marketplace/$id';
  static String order(int id) => '/orders/$id';
}
