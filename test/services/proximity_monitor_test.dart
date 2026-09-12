import 'package:flutter_test/flutter_test.dart';
import 'package:follo_cart/models/follow_model.dart';
import 'package:follo_cart/models/food_cart_model.dart';
import 'package:follo_cart/models/notification_model.dart';
import 'package:follo_cart/services/alert_cooldown_store.dart';
import 'package:follo_cart/services/proximity_monitor.dart';
import 'package:latlong2/latlong.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late FakeNotificationRepository notifications;
  late RecordingNotificationGateway gateway;
  late ProximityMonitor monitor;

  const userPosition = LatLng(23.8103, 90.4125);
  final nearCart = testCart(id: 'near', name: 'Momo House', latitude: 23.8130);
  final farCart = testCart(id: 'far', name: 'Far Cart', latitude: 24.5);

  FollowModel followOf(String cartId, {bool notify = true, int km = 5}) =>
      FollowModel(
        id: FollowModel.idFor('u1', cartId),
        userId: 'u1',
        cartId: cartId,
        followedAt: now,
        notificationsEnabled: notify,
        proximityAlertKm: km,
      );

  setUp(() async {
    now = DateTime(2026, 9, 11, 12);
    notifications = FakeNotificationRepository();
    gateway = RecordingNotificationGateway();
    monitor = ProximityMonitor(
      cooldowns: AlertCooldownStore(await testStore(), clock: () => now),
      gateway: gateway,
      notifications: notifications,
      clock: () => now,
    );
  });

  Future<List<Object>> run({
    String? userId = 'u1',
    LatLng? position = userPosition,
    List<FoodCartModel>? carts,
    List<FollowModel>? follows,
    bool alertsEnabled = true,
    bool force = false,
  }) async {
    return monitor.evaluate(
      userId: userId,
      position: position,
      carts: carts ?? <FoodCartModel>[nearCart, farCart],
      follows: follows ?? <FollowModel>[followOf('near')],
      alertsEnabled: alertsEnabled,
      force: force,
    );
  }

  test('raises one alert and writes it to the feed', () async {
    final alerts = await run();

    expect(alerts, hasLength(1));
    expect(gateway.shown, hasLength(1));
    expect(gateway.shown.single.title, contains('Momo House'));
    // The real distance, not a clamped "5.0 km".
    expect(gateway.shown.single.body, isNot(contains('5.0 km')));
    expect(gateway.shown.single.deeplink, 'cart/near');

    expect(notifications.feedFor('u1'), hasLength(1));
    expect(
      notifications.feedFor('u1').single.type,
      NotificationType.proximity,
    );
  });

  test('does not alert twice inside the cooldown', () async {
    await run();
    expect(gateway.shown, hasLength(1));

    now = now.add(const Duration(minutes: 5));
    await run(force: true);
    expect(gateway.shown, hasLength(1));
  });

  test('alerts again after the cooldown expires', () async {
    await run();
    now = now.add(const Duration(hours: 7));
    await run(force: true);

    expect(gateway.shown, hasLength(2));
  });

  test('stays silent for guests', () async {
    final alerts = await run(userId: null);
    expect(alerts, isEmpty);
    expect(gateway.shown, isEmpty);
  });

  test('stays silent when the user turned alerts off', () async {
    await run(alertsEnabled: false);
    expect(gateway.shown, isEmpty);
  });

  test('respects a per-follow notification toggle', () async {
    await run(follows: <FollowModel>[followOf('near', notify: false)]);
    expect(gateway.shown, isEmpty);
  });

  test('ignores carts the user does not follow', () async {
    await run(follows: <FollowModel>[followOf('far')]);
    expect(gateway.shown, isEmpty);
  });

  test('throttles rapid position updates', () async {
    await run();
    gateway.shown.clear();

    // A second cart enters range, but within the throttle window.
    final another = testCart(id: 'near2', latitude: 23.8131);
    now = now.add(const Duration(seconds: 10));
    await run(
      carts: <FoodCartModel>[nearCart, another],
      follows: <FollowModel>[followOf('near'), followOf('near2')],
    );
    expect(gateway.shown, isEmpty);
  });
}
