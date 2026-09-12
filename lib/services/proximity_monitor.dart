import 'package:latlong2/latlong.dart';

import '../core/app_constants.dart';
import '../core/id_generator.dart';
import '../models/follow_model.dart';
import '../models/food_cart_model.dart';
import '../models/notification_model.dart';
import '../models/proximity_alert_model.dart';
import '../repositories/notification_repository.dart';
import 'alert_cooldown_store.dart';
import 'notification_gateway.dart';
import 'proximity_service.dart';

/// Turns "user is near a followed cart" into exactly one notification.
///
/// Sits between the pure maths in `ProximityService` and the persisted cooldown
/// ledger, so all the stateful policy lives in one testable place.
class ProximityMonitor {
  ProximityMonitor({
    required AlertCooldownStore cooldowns,
    required NotificationGateway gateway,
    required NotificationRepository notifications,
    DateTime Function()? clock,
  })  : _cooldowns = cooldowns,
        _gateway = gateway,
        _notifications = notifications,
        _clock = clock ?? DateTime.now;

  final AlertCooldownStore _cooldowns;
  final NotificationGateway _gateway;
  final NotificationRepository _notifications;
  final DateTime Function() _clock;

  DateTime? _lastRun;
  LatLng? _lastEvaluatedPosition;

  /// Movement that always earns a fresh evaluation, no matter how recently one
  /// ran. Without this, a user walking into range could wait out the whole
  /// throttle window before being told.
  static const double _significantMoveMeters = 100;

  /// Evaluates the current position against followed carts.
  ///
  /// Returns the alerts actually raised, so the caller can surface them
  /// in-app (the web path, where there is no system notification).
  Future<List<ProximityAlertModel>> evaluate({
    required String? userId,
    required LatLng? position,
    required List<FoodCartModel> carts,
    required List<FollowModel> follows,
    required bool alertsEnabled,
    bool force = false,
  }) async {
    // Guests have no identity to notify.
    if (userId == null || position == null || !alertsEnabled) {
      return const <ProximityAlertModel>[];
    }

    final now = _clock();
    if (!force && _lastRun != null && _lastEvaluatedPosition != null) {
      final movedMeters = ProximityService.calculateDistanceKm(
            lat1: _lastEvaluatedPosition!.latitude,
            lon1: _lastEvaluatedPosition!.longitude,
            lat2: position.latitude,
            lon2: position.longitude,
          ) *
          1000;

      // Throttle only a user who is effectively standing still; real movement
      // is always worth re-checking.
      if (movedMeters < _significantMoveMeters &&
          now.difference(_lastRun!) < AppConstants.proximityPositionThrottle) {
        return const <ProximityAlertModel>[];
      }
    }

    final notifiable = <String, FollowModel>{
      for (final follow in follows)
        if (follow.notificationsEnabled) follow.cartId: follow,
    };
    // Nothing to evaluate: do not spend the throttle window on a no-op run.
    if (notifiable.isEmpty) return const <ProximityAlertModel>[];

    _lastRun = now;
    _lastEvaluatedPosition = position;

    double thresholdFor(String cartId) =>
        (notifiable[cartId]?.proximityAlertKm ?? AppConstants.alertRadiusKm)
            .toDouble();

    // Exit-reset before evaluating, so a user who left and came back can alert
    // again immediately rather than waiting out a stale cooldown.
    final observed = <String, double>{};
    for (final cart in carts) {
      if (!notifiable.containsKey(cart.id)) continue;
      observed[cart.id] = ProximityService.calculateDistanceKm(
        lat1: position.latitude,
        lon1: position.longitude,
        lat2: cart.latitude,
        lon2: cart.longitude,
      );
    }
    await _cooldowns.applyExitResets(
      userId: userId,
      observedDistancesKm: observed,
      thresholdForCart: thresholdFor,
    );

    if (_cooldowns.hasHitHourlyCap(userId)) {
      return const <ProximityAlertModel>[];
    }

    final alerts = ProximityService.checkForNearbyCarts(
      userLat: position.latitude,
      userLng: position.longitude,
      carts: carts,
      followedCartIds: notifiable.keys.toSet(),
      userId: userId,
      thresholdForCart: thresholdFor,
      suppressedCartIds: _cooldowns.suppressedCartIds(userId),
      clock: _clock,
      idFactory: () => newId('alert'),
    );
    if (alerts.isEmpty) return const <ProximityAlertModel>[];

    final delivered = <ProximityAlertModel>[];
    final inbox = <NotificationModel>[];

    for (final alert in alerts) {
      if (_cooldowns.hasHitHourlyCap(userId)) break;

      final message =
          ProximityService.notificationMessage(alert.cartName, alert.distanceKm);

      inbox.add(NotificationModel(
        id: newId('note'),
        userId: userId,
        cartId: alert.cartId,
        cartName: alert.cartName,
        type: NotificationType.proximity,
        message: message,
        distanceKm: alert.distanceKm,
        createdAt: alert.triggeredAt,
      ));

      await _gateway.show(
        id: alert.id,
        title: '${alert.cartName} is nearby',
        body: message,
        deeplink: 'cart/${alert.cartId}',
      );

      await _cooldowns.recordAlert(
        userId: userId,
        cartId: alert.cartId,
        distanceKm: alert.distanceKm,
      );

      delivered.add(alert.copyWith(isDelivered: true));
    }

    if (inbox.isNotEmpty) await _notifications.pushAll(inbox);
    return delivered;
  }

  /// Lets a sign-out or a fresh follow force the next evaluation to run.
  void reset() {
    _lastRun = null;
    _lastEvaluatedPosition = null;
  }
}
