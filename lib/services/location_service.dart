import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_constants.dart';

enum LocationFailure { serviceDisabled, permissionDenied, permanentlyDenied, unknown }

class LocationException implements Exception {
  const LocationException(this.failure, this.message);
  final LocationFailure failure;
  final String message;
  @override
  String toString() => message;
}

/// Injectable geolocator wrapper.
///
/// The prototype called `Geolocator` statics straight from the widget, which
/// meant every widget test hit `MissingPluginException`, landed silently in a
/// catch block, and still reported a pass. Tests now supply a fake.
abstract class LocationService {
  Future<LatLng> currentPosition();
  Stream<LatLng> watchPosition({bool background = false});
  Future<bool> ensurePermission({bool background = false});
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<bool> ensurePermission({bool background = false}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        LocationFailure.serviceDisabled,
        'Location services are turned off.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        LocationFailure.permanentlyDenied,
        'Location permission is blocked in system settings.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(
        LocationFailure.permissionDenied,
        'Location permission was not granted.',
      );
    }

    // Background ("Always") is requested only when the user opts into a
    // background feature. Asking upfront collapses grant rates.
    if (background &&
        permission == LocationPermission.whileInUse &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      await Geolocator.requestPermission();
    }
    return true;
  }

  @override
  Future<LatLng> currentPosition() async {
    await ensurePermission();
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return LatLng(position.latitude, position.longitude);
  }

  @override
  Stream<LatLng> watchPosition({bool background = false}) {
    return Geolocator.getPositionStream(
      locationSettings: _settings(background: background),
    ).map((p) => LatLng(p.latitude, p.longitude));
  }

  static LocationSettings _settings({required bool background}) {
    const filter = AppConstants.broadcastDistanceFilterMeters;

    if (kIsWeb) {
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: filter,
      );
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: filter,
          intervalDuration: const Duration(seconds: 30),
          // A foreground service keeps the Dart isolate alive while the app is
          // backgrounded. Only attached when the user opted in.
          foregroundNotificationConfig: background
              ? const ForegroundNotificationConfig(
                  notificationTitle: 'Follo Cart is using your location',
                  notificationText:
                      'Keeping your cart updates and 5 km alerts running.',
                  notificationChannelName: 'Location sharing',
                  enableWakeLock: true,
                  setOngoing: true,
                )
              : null,
        ),
      TargetPlatform.iOS || TargetPlatform.macOS => AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: filter,
          activityType: ActivityType.otherNavigation,
          pauseLocationUpdatesAutomatically: true,
          showBackgroundLocationIndicator: background,
          allowBackgroundLocationUpdates: background,
        ),
      _ => const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: filter,
        ),
    };
  }
}
