import 'dart:math';

import '../core/app_constants.dart';
import '../core/id_generator.dart';
import '../models/food_cart_model.dart';
import '../models/proximity_alert_model.dart';

/// Pure proximity maths. No clocks, no id generation, no I/O of its own -
/// everything time-dependent is injected, which is what makes the alert
/// pipeline testable.
abstract final class ProximityService {
  static const double proximityThresholdKm = AppConstants.alertRadiusKm;
  static const int checkIntervalMinutes = 10;

  static const double _earthRadiusKm = 6371.0;

  static double calculateDistanceKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;

  /// Carts within alert range, nearest first.
  ///
  /// [followedCartIds] is required. The previous version alerted on *every*
  /// cart in range regardless of whether the user followed it, which made the
  /// feature unusable in a dense area.
  static List<ProximityAlertModel> checkForNearbyCarts({
    required double userLat,
    required double userLng,
    required List<FoodCartModel> carts,
    required Set<String> followedCartIds,
    required String userId,
    double Function(String cartId)? thresholdForCart,
    Set<String> suppressedCartIds = const <String>{},
    Set<String> excludedCartIds = const <String>{},
    DateTime Function()? clock,
    String Function()? idFactory,
  }) {
    final now = (clock ?? DateTime.now)();
    final makeId = idFactory ?? newId;

    final hits = <(FoodCartModel, double)>[];
    for (final cart in carts) {
      if (!followedCartIds.contains(cart.id)) continue;
      if (!cart.isActive) continue;
      if (suppressedCartIds.contains(cart.id)) continue;
      if (excludedCartIds.contains(cart.id)) continue;

      final distance = calculateDistanceKm(
        lat1: userLat,
        lon1: userLng,
        lat2: cart.latitude,
        lon2: cart.longitude,
      );
      final threshold =
          thresholdForCart?.call(cart.id) ?? proximityThresholdKm;
      if (distance <= threshold) hits.add((cart, distance));
    }

    hits.sort((a, b) => a.$2.compareTo(b.$2));

    return hits
        .map((hit) => ProximityAlertModel(
              id: makeId(),
              userId: userId,
              cartId: hit.$1.id,
              cartName: hit.$1.name,
              distanceKm: hit.$2,
              triggeredAt: now,
            ))
        .toList();
  }

  /// Reports the real distance.
  ///
  /// The previous implementation clamped upward (`distanceKm < 5 ? 5 : d`), so
  /// a cart 800 m away announced itself as "within 5.0 km" - the alert was
  /// least accurate exactly when it mattered most.
  static String notificationMessage(String cartName, double distanceKm) {
    final label = distanceKm < 1
        ? '${(distanceKm * 1000).round()} m'
        : '${distanceKm.toStringAsFixed(1)} km';
    return '$cartName is $label away. Check it out now.';
  }
}
