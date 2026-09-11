import 'package:follo_cart/models/food_cart_model.dart';
import 'package:follo_cart/services/proximity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates distance for a nearby cart within 3 km', () {
    final distance = ProximityService.calculateDistanceKm(
      lat1: 23.8103,
      lon1: 90.4125,
      lat2: 23.8125,
      lon2: 90.4160,
    );

    expect(distance, isNonNegative);
    expect(distance, lessThanOrEqualTo(3.0));
  });

  test('creates a proximity alert when user is within 3 km', () {
    final alerts = ProximityService.checkForNearbyCarts(
      userLat: 23.8103,
      userLng: 90.4125,
      carts: FoodCartModel.demoCarts(),
      userId: 'user-1',
    );

    expect(alerts, isNotEmpty);
    expect(alerts.first.distanceKm, lessThanOrEqualTo(3.0));
  });
}
