import 'package:agrilink_mobile/features/marketplace/application/listing_rules.dart';
import 'package:agrilink_mobile/features/marketplace/data/harvest_listing.dart';
import 'package:agrilink_mobile/features/marketplace/data/marketplace_enums.dart';
import 'package:agrilink_mobile/features/marketplace/data/order.dart';
import 'package:agrilink_mobile/features/marketplace/data/purchase_request.dart';
import 'package:flutter_test/flutter_test.dart';

import 'marketplace_fixtures.dart';

void main() {
  group('enums', () {
    test('read the API strings and keep them in apiName', () {
      for (final status in HarvestStatus.values) {
        expect(HarvestStatus.fromApi(status.apiName), status);
      }
      for (final status in PurchaseRequestStatus.values) {
        expect(PurchaseRequestStatus.fromApi(status.apiName), status);
      }
      for (final status in OrderStatus.values) {
        expect(OrderStatus.fromApi(status.apiName), status);
      }
      expect(RequestAction.accept.apiName, 'accept');
    });

    test('an unknown value is a clear error, not a wrong status', () {
      expect(() => HarvestStatus.fromApi('Rotten'), throwsFormatException);
      expect(() => PurchaseRequestStatus.fromApi(null), throwsFormatException);
      expect(() => OrderStatus.fromApi('confirmed'), throwsFormatException);
    });

    test('only a confirmed order can be completed or cancelled', () {
      expect(OrderStatus.confirmed.canChange, isTrue);
      expect(OrderStatus.completed.canChange, isFalse);
      expect(OrderStatus.cancelled.canChange, isFalse);
    });
  });

  group('HarvestListing', () {
    test('reads the API response, whole numbers included', () {
      final listing = HarvestListing.fromJson(listingJson());
      expect(listing.id, 7);
      expect(listing.farmerProfileId, 11);
      expect(listing.cropType, 'Paddy');
      expect(listing.quantity, 500.0);
      expect(listing.availableQuantity, 400.0);
      expect(listing.pricePerUnit, 120.0);
      expect(listing.status, HarvestStatus.active);
      expect(listing.harvestDate, DateTime(2026, 9, 20));
      expect(listing.createdAt, DateTime.utc(2026, 9, 21, 8, 30));
    });

    test('a cancelled listing can be reopened only with quantity left', () {
      expect(HarvestListing.fromJson(listingJson(status: 'Cancelled')).canReopen, isTrue);
      expect(
        HarvestListing.fromJson(listingJson(status: 'Cancelled', availableQuantity: 0)).canReopen,
        isFalse,
      );
      expect(HarvestListing.fromJson(listingJson()).canReopen, isFalse);
    });

    test('the create body sends the harvest date as a plain date', () {
      final body = CreateHarvestListingRequest(
        cropId: 3,
        quantity: 250.5,
        harvestDate: DateTime(2026, 9, 5, 23, 59),
        pricePerUnit: 95,
        location: 'Wariyapola',
      ).toJson();
      expect(body, {
        'cropId': 3,
        'quantity': 250.5,
        'harvestDate': '2026-09-05',
        'pricePerUnit': 95.0,
        'location': 'Wariyapola',
      });
    });

    test('the update body sends only what changed', () {
      expect(const UpdateHarvestListingRequest(status: HarvestStatus.cancelled).toJson(), {
        'status': 'Cancelled',
      });
      expect(
        UpdateHarvestListingRequest(
          pricePerUnit: 130,
          location: 'Kuliyapitiya',
          harvestDate: DateTime(2026, 1, 2),
        ).toJson(),
        {'pricePerUnit': 130.0, 'location': 'Kuliyapitiya', 'harvestDate': '2026-01-02'},
      );
    });
  });

  group('PurchaseRequest', () {
    test('reads the API response and works out the total', () {
      final request = PurchaseRequest.fromJson(requestJson(requestedQuantity: 12.5));
      expect(request.id, 21);
      expect(request.status, PurchaseRequestStatus.pending);
      expect(request.buyerBusinessName, 'Silva Traders');
      expect(request.total, 1500.0);
    });

    test('the body leaves out a blank message', () {
      expect(
        const CreatePurchaseRequestRequest(
          harvestId: 7,
          requestedQuantity: 10,
          message: '  ',
        ).toJson(),
        {'harvestId': 7, 'requestedQuantity': 10.0},
      );
      expect(
        const CreatePurchaseRequestRequest(
          harvestId: 7,
          requestedQuantity: 10,
          message: ' Hi ',
        ).toJson()['message'],
        'Hi',
      );
    });
  });

  group('Order', () {
    test('reads both parties and treats blank values as missing', () {
      final order = Order.fromJson(orderJson(buyerPhone: null));
      expect(order.status, OrderStatus.confirmed);
      expect(order.completedAt, isNull);
      expect(order.totalAmount, 6000.0);
      expect(order.farmer.phone, '0712345678');
      expect(order.farmer.businessName, isNull);
      expect(order.buyer.phone, isNull);
      expect(order.buyer.photoUrl, isNull);
      expect(order.buyer.displayName, 'Silva Traders');
      expect(order.farmer.displayName, 'Sunil Perera');
    });

    test('the other party depends on who is looking', () {
      final order = Order.fromJson(orderJson());
      expect(order.otherParty(viewerIsFarmer: true).name, 'Nimal Silva');
      expect(order.otherParty(viewerIsFarmer: false).name, 'Sunil Perera');
    });
  });

  group('PriceRange', () {
    final listings = [
      HarvestListing.fromJson(listingJson(id: 1, pricePerUnit: 80)),
      HarvestListing.fromJson(listingJson(id: 2, pricePerUnit: 130)),
      HarvestListing.fromJson(listingJson(id: 3, pricePerUnit: 200)),
    ];

    List<int> ids(PriceRange range) => [for (final l in range.apply(listings)) l.id];

    test('no limits keeps everything', () {
      expect(PriceRange.parse('', ' ').isSet, isFalse);
      expect(ids(PriceRange.any), [1, 2, 3]);
    });

    test('filters by minimum, maximum or both, ends included', () {
      expect(ids(PriceRange.parse('120', '')), [2, 3]);
      expect(ids(PriceRange.parse('', '130')), [1, 2]);
      expect(ids(PriceRange.parse('100', '150')), [2]);
    });

    test('text that is not a number means no limit', () {
      expect(ids(PriceRange.parse('abc', '150')), [1, 2]);
    });
  });

  group('isOwnListing', () {
    final listing = HarvestListing.fromJson(listingJson(farmerProfileId: 15));

    test('matches the farmer who made it', () {
      expect(isOwnListing(listing, 15), isTrue);
    });

    test('is false for another farmer and for users with no farmer profile', () {
      expect(isOwnListing(listing, 16), isFalse);
      expect(isOwnListing(listing, null), isFalse);
    });
  });
}
