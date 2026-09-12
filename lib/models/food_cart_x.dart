import 'package:latlong2/latlong.dart';

import '../services/proximity_service.dart';
import 'food_cart_model.dart';

extension FoodCartDistance on FoodCartModel {
  /// Live distance from the user. Null when the position is unknown, so the UI
  /// can say so honestly instead of inventing a number.
  double? distanceKmFrom(LatLng? user) {
    if (user == null) return null;
    return ProximityService.calculateDistanceKm(
      lat1: user.latitude,
      lon1: user.longitude,
      lat2: latitude,
      lon2: longitude,
    );
  }

  LatLng get position => LatLng(latitude, longitude);
}
