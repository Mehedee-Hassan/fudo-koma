import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_constants.dart';
import '../models/follow_model.dart';
import '../models/food_cart_model.dart';
import '../models/proximity_alert_model.dart';
import '../repositories/local/local_keys.dart';
import '../repositories/local/local_store.dart';
import '../services/proximity_monitor.dart';

/// Drives `ProximityMonitor` from the three inputs it needs.
///
/// Three triggers, all of them necessary:
/// 1. a new position (the user walks toward a cart),
/// 2. a cart-list change (a *cart* moves toward a stationary user - the
///    prototype had no path for this at all),
/// 3. a periodic heartbeat, which finally gives `checkIntervalMinutes` the
///    consumer it never had.
class ProximityController extends ChangeNotifier {
  ProximityController({
    required ProximityMonitor monitor,
    LocalStore? store,
  })  : _monitor = monitor,
        _store = store {
    _heartbeat = Timer.periodic(
      AppConstants.proximityCheckInterval,
      (_) => unawaited(evaluate(force: true)),
    );
  }

  final ProximityMonitor _monitor;
  final LocalStore? _store;
  late final Timer _heartbeat;

  String? _userId;
  LatLng? _position;
  List<FoodCartModel> _carts = const <FoodCartModel>[];
  List<FollowModel> _follows = const <FollowModel>[];
  bool _alertsEnabled = true;
  String? _ownCartId;
  bool _running = false;

  List<ProximityAlertModel> _recentAlerts = const <ProximityAlertModel>[];
  List<ProximityAlertModel> get recentAlerts => _recentAlerts;

  bool get backgroundAlertsEnabled =>
      _store?.getBool(LocalKeys.backgroundAlerts) ?? false;

  Future<void> setBackgroundAlertsEnabled(bool value) async {
    await _store?.setBool(LocalKeys.backgroundAlerts, value);
    notifyListeners();
  }

  /// Called from the proxy provider whenever any input changes.
  void update({
    required String? userId,
    required LatLng? position,
    required List<FoodCartModel> carts,
    required List<FollowModel> follows,
    required bool alertsEnabled,
    String? ownCartId,
  }) {
    final positionChanged = position != _position;
    final cartsChanged = !identical(carts, _carts) &&
        !listEquals(_cartSignature(carts), _cartSignature(_carts));
    final userChanged = userId != _userId;
    final followsChanged = !listEquals(
      _followSignature(follows),
      _followSignature(_follows),
    );

    _userId = userId;
    _position = position;
    _carts = carts;
    _follows = follows;
    _alertsEnabled = alertsEnabled;
    _ownCartId = ownCartId;

    if (userChanged) _monitor.reset();
    if (positionChanged || cartsChanged || userChanged || followsChanged) {
      // Just-followed carts skip the throttle: the user asked for this cart
      // right now, so making them wait out a window would feel broken.
      unawaited(evaluate(force: followsChanged || userChanged));
    }
  }

  Future<void> evaluate({bool force = false}) async {
    if (_running) return;
    _running = true;
    try {
      final alerts = await _monitor.evaluate(
        userId: _userId,
        position: _position,
        // An owner should never be alerted that they are near themselves.
        carts: _ownCartId == null
            ? _carts
            : _carts.where((c) => c.id != _ownCartId).toList(),
        follows: _follows,
        alertsEnabled: _alertsEnabled,
        force: force,
      );
      if (alerts.isNotEmpty) {
        _recentAlerts = alerts;
        notifyListeners();
      }
    } catch (error) {
      debugPrint('ProximityController.evaluate: $error');
    } finally {
      _running = false;
    }
  }

  void clearRecentAlerts() {
    if (_recentAlerts.isEmpty) return;
    _recentAlerts = const <ProximityAlertModel>[];
    notifyListeners();
  }

  static List<String> _followSignature(List<FollowModel> follows) => follows
      .map((f) => '${f.cartId}:${f.notificationsEnabled}:${f.proximityAlertKm}')
      .toList();

  /// Position-sensitive signature: a cart list is "changed" for proximity
  /// purposes only when membership or a coordinate actually moved.
  static List<String> _cartSignature(List<FoodCartModel> carts) => carts
      .map((c) => '${c.id}:${c.latitude}:${c.longitude}:${c.isActive}')
      .toList();

  @override
  void dispose() {
    _heartbeat.cancel();
    super.dispose();
  }
}
