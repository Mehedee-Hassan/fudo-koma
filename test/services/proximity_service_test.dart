import 'package:flutter_test/flutter_test.dart';
import 'package:follo_cart/core/app_constants.dart';
import 'package:follo_cart/models/food_cart_model.dart';
import 'package:follo_cart/services/proximity_service.dart';

import '../support/fakes.dart';

void main() {
  final clock = DateTime(2026, 9, 11, 12);
  var counter = 0;
  String ids() => 'alert-${counter++}';

  setUp(() => counter = 0);

  group('calculateDistanceKm', () {
    test('returns zero for the same point', () {
      expect(
        ProximityService.calculateDistanceKm(
          lat1: 23.8103,
          lon1: 90.4125,
          lat2: 23.8103,
          lon2: 90.4125,
        ),
        closeTo(0, 0.0001),
      );
    });

    test('matches a known distance', () {
      // Dhaka (23.8103, 90.4125) -> Chittagong (22.3569, 91.7832) is ~215 km.
      final km = ProximityService.calculateDistanceKm(
        lat1: 23.8103,
        lon1: 90.4125,
        lat2: 22.3569,
        lon2: 91.7832,
      );
      expect(km, closeTo(215, 5));
    });
  });

  group('checkForNearbyCarts', () {
    final near = testCart(id: 'near', latitude: 23.8130, longitude: 90.4125);
    final mid = testCart(id: 'mid', latitude: 23.8400, longitude: 90.4125);
    final far = testCart(id: 'far', latitude: 24.5000, longitude: 90.4125);

    List<FoodCartModel> allCarts() => <FoodCartModel>[near, mid, far];

    test('alerts for a followed cart inside the radius', () {
      final alerts = ProximityService.checkForNearbyCarts(
        userLat: 23.8103,
        userLng: 90.4125,
        carts: allCarts(),
        followedCartIds: <String>{'near'},
        userId: 'user-1',
        clock: () => clock,
        idFactory: ids,
      );

      expect(alerts, hasLength(1));
      expect(alerts.single.cartId, 'near');
      expect(alerts.single.distanceKm, lessThan(AppConstants.alertRadiusKm));
      expect(alerts.single.triggeredAt, clock);
    });

    test('ignores carts outside the radius', () {
      final alerts = ProximityService.checkForNearbyCarts(
        userLat: 23.8103,
        userLng: 90.4125,
        carts: allCarts(),
        followedCartIds: <String>{'far'},
        userId: 'user-1',
        clock: () => clock,
        idFactory: ids,
      );
      expect(alerts, isEmpty);
    });

    test('never alerts for a cart the user does not follow', () {
      // The previous implementation alerted on every cart in range, which made
      // the feature unusable anywhere dense.
      final alerts = ProximityService.checkForNearbyCarts(
        userLat: 23.8103,
        userLng: 90.4125,
        carts: allCarts(),
        followedCartIds: const <String>{},
        userId: 'user-1',
        clock: () => clock,
        idFactory: ids,
      );
      expect(alerts, isEmpty);
    });

    test('orders results nearest first', () {
      final alerts = ProximityService.checkForNearbyCarts(
        userLat: 23.8103,
        userLng: 90.4125,
        carts: allCarts(),
        followedCartIds: <String>{'near', 'mid'},
        userId: 'user-1',
        clock: () => clock,
        idFactory: ids,
      );

      expect(alerts.map((a) => a.cartId).toList(), <String>['near', 'mid']);
      expect(alerts.first.distanceKm, lessThan(alerts.last.distanceKm));
    });

    test('honours a per-cart threshold', () {
      final alerts = ProximityService.checkForNearbyCarts(
        userLat: 23.8103,
        userLng: 90.4125,
        carts: allCarts(),
        followedCartIds: <String>{'near', 'mid'},
        userId: 'user-1',
        // 'mid' is ~3.3 km away, so a 1 km threshold must exclude it.
        thresholdForCart: (cartId) => cartId == 'mid' ? 1.0 : 5.0,
        clock: () => clock,
        idFactory: ids,
      );
      expect(alerts.map((a) => a.cartId), <String>['near']);
    });

    test('skips suppressed and inactive carts', () {
      final hidden = testCart(
        id: 'hidden',
        latitude: 23.8130,
        longitude: 90.4125,
        isActive: false,
      );

      final alerts = ProximityService.checkForNearbyCarts(
        userLat: 23.8103,
        userLng: 90.4125,
        carts: <FoodCartModel>[near, hidden],
        followedCartIds: <String>{'near', 'hidden'},
        userId: 'user-1',
        suppressedCartIds: <String>{'near'},
        clock: () => clock,
        idFactory: ids,
      );
      expect(alerts, isEmpty);
    });
  });

  group('notificationMessage', () {
    test('reports the real distance in kilometres', () {
      // The old version clamped upward, so a 2.9 km cart announced "5.0 km".
      final message = ProximityService.notificationMessage('Momo House', 2.9);
      expect(message, contains('2.9 km'));
      expect(message, isNot(contains('5.0 km')));
    });

    test('switches to metres below one kilometre', () {
      final message = ProximityService.notificationMessage('Momo House', 0.82);
      expect(message, contains('820 m'));
      expect(message, isNot(contains('km')));
    });
  });

  test('radius constants agree across the app', () {
    expect(ProximityService.proximityThresholdKm, AppConstants.alertRadiusKm);
    expect(AppConstants.alertRadiusKm, 5.0);
  });
}
