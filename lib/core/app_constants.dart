import 'package:latlong2/latlong.dart';

/// Single source of truth for values that used to be duplicated across
/// `main.dart` (the map centre was declared in two places and the two copies
/// had already drifted apart).
abstract final class AppConstants {
  /// Fallback map centre used until the device reports a real position.
  static const LatLng defaultMapCenter = LatLng(23.8103, 90.4125);
  static const double defaultMapZoom = 13.0;

  /// The alert radius the whole product is built around. The map circle, the
  /// proximity monitor, the per-follow default and all UI copy read from here.
  static const double alertRadiusKm = 5.0;
  static double get alertRadiusMeters => alertRadiusKm * 1000;

  /// Owner live-location publishing.
  static const int broadcastDistanceFilterMeters = 50;
  static const Duration broadcastMinWriteInterval = Duration(seconds: 30);

  /// Republish a "cart moved" update only after this much real movement, so a
  /// cart drifting around one block does not spam every follower's feed.
  static const double movedUpdateThresholdMeters = 250;

  /// Proximity alert policy.
  static const Duration proximityCooldown = Duration(hours: 6);
  static const Duration proximityCheckInterval = Duration(minutes: 10);
  static const Duration proximityPositionThrottle = Duration(minutes: 1);
  static const int maxProximityAlertsPerHour = 5;

  /// Clear a cart's cooldown once the user is observed this far outside the
  /// radius, so a genuine re-approach can alert again.
  static const double cooldownResetMultiplier = 1.5;

  static const Duration cooldownRetention = Duration(days: 7);
}
