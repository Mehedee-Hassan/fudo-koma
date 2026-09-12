import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_constants.dart';
import '../services/location_service.dart';

class LocationController extends ChangeNotifier {
  LocationController(this._service);

  final LocationService _service;
  StreamSubscription<LatLng>? _sub;

  LatLng? _position;
  bool _isLocating = false;
  bool _tracking = false;
  bool _backgroundEnabled = false;
  String? _error;
  LocationFailure? _failure;

  /// Null until a real fix arrives, so the UI can say "finding you" rather than
  /// silently presenting the Dhaka fallback as the user's position.
  LatLng? get position => _position;
  LatLng get positionOrDefault => _position ?? AppConstants.defaultMapCenter;
  bool get hasFix => _position != null;
  bool get isLocating => _isLocating;
  bool get isTracking => _tracking;
  bool get backgroundEnabled => _backgroundEnabled;
  String? get error => _error;
  LocationFailure? get failure => _failure;

  Future<void> refresh() async {
    _isLocating = true;
    _error = null;
    _failure = null;
    notifyListeners();

    try {
      _position = await _service.currentPosition();
      _error = null;
      _failure = null;
    } on LocationException catch (error) {
      _error = error.message;
      _failure = error.failure;
    } catch (error) {
      _error = 'Could not read your location.';
      _failure = LocationFailure.unknown;
      debugPrint('LocationController.refresh: $error');
    } finally {
      _isLocating = false;
      notifyListeners();
    }
  }

  Future<void> startTracking({bool background = false}) async {
    if (_tracking && _backgroundEnabled == background) return;
    await stopTracking();

    try {
      await _service.ensurePermission(background: background);
      _sub = _service.watchPosition(background: background).listen(
        (position) {
          _position = position;
          _error = null;
          notifyListeners();
        },
        onError: (Object error) {
          _error = error is LocationException
              ? error.message
              : 'Location updates stopped.';
          notifyListeners();
        },
      );
      _tracking = true;
      _backgroundEnabled = background;
    } on LocationException catch (error) {
      _error = error.message;
      _failure = error.failure;
    } finally {
      notifyListeners();
    }
  }

  Future<void> stopTracking() async {
    await _sub?.cancel();
    _sub = null;
    _tracking = false;
    _backgroundEnabled = false;
    notifyListeners();
  }

  @override
  void dispose() {
    // Leaking this subscription would leave a GPS stream running forever.
    _sub?.cancel();
    super.dispose();
  }
}
