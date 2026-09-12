import 'package:flutter_test/flutter_test.dart';
import 'package:follo_cart/services/alert_cooldown_store.dart';

import '../support/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  DateTime clock() => now;

  setUp(() => now = DateTime(2026, 9, 11, 12));

  Future<AlertCooldownStore> build() async =>
      AlertCooldownStore(await testStore(), clock: clock);

  test('suppresses a cart for the cooldown window, then releases it', () async {
    final store = await build();
    await store.recordAlert(userId: 'u1', cartId: 'c1', distanceKm: 1.2);

    expect(store.suppressedCartIds('u1'), contains('c1'));

    now = now.add(const Duration(hours: 1));
    expect(store.suppressedCartIds('u1'), contains('c1'));

    now = now.add(const Duration(hours: 6));
    expect(store.suppressedCartIds('u1'), isEmpty);
  });

  test('scopes cooldowns per user', () async {
    final store = await build();
    await store.recordAlert(userId: 'u1', cartId: 'c1', distanceKm: 1.0);

    expect(store.suppressedCartIds('u2'), isEmpty);
  });

  test('exit-reset clears the cooldown once well outside the radius', () async {
    final store = await build();
    await store.recordAlert(userId: 'u1', cartId: 'c1', distanceKm: 1.0);
    expect(store.suppressedCartIds('u1'), contains('c1'));

    // Still inside 7.5 km (5 km * 1.5), so the cooldown must hold.
    await store.applyExitResets(
      userId: 'u1',
      observedDistancesKm: <String, double>{'c1': 6.0},
      thresholdForCart: (_) => 5.0,
    );
    expect(store.suppressedCartIds('u1'), contains('c1'));

    // Beyond the reset band: a real re-approach should alert again.
    await store.applyExitResets(
      userId: 'u1',
      observedDistancesKm: <String, double>{'c1': 9.0},
      thresholdForCart: (_) => 5.0,
    );
    expect(store.suppressedCartIds('u1'), isEmpty);
  });

  test('enforces the hourly cap', () async {
    final store = await build();
    for (var i = 0; i < 5; i++) {
      await store.recordAlert(userId: 'u1', cartId: 'c$i', distanceKm: 1.0);
    }
    expect(store.hasHitHourlyCap('u1'), isTrue);

    now = now.add(const Duration(hours: 2));
    expect(store.hasHitHourlyCap('u1'), isFalse);
  });

  test('prunes entries older than the retention window', () async {
    final store = await build();
    await store.recordAlert(userId: 'u1', cartId: 'c1', distanceKm: 1.0);

    now = now.add(const Duration(days: 8));
    expect(store.suppressedCartIds('u1'), isEmpty);
    expect(store.hasHitHourlyCap('u1'), isFalse);
  });
}
