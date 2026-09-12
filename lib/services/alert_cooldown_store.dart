import 'dart:convert';

import '../core/app_constants.dart';
import '../repositories/local/local_keys.dart';
import '../repositories/local/local_store.dart';

/// Persisted "already alerted" ledger.
///
/// Without this, every position update inside the radius fires another
/// notification. Three rules, in order of importance:
///
/// 1. A 6-hour cooldown per (user, cart) - roughly lunch and dinner.
/// 2. Exit-reset: once the user is seen beyond `threshold * 1.5`, the cooldown
///    clears immediately. This kills flapping at the boundary without a fixed
///    hysteresis band, and lets a real re-approach alert again the same day.
/// 3. A global cap of 5 proximity alerts per user per hour, which protects
///    someone who follows 30 carts in a dense area.
class AlertCooldownStore {
  AlertCooldownStore(this._store, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final LocalStore _store;
  final DateTime Function() _clock;

  Map<String, _Entry> _read() {
    final raw = _store.getString(LocalKeys.alertCooldowns);
    if (raw == null || raw.isEmpty) return <String, _Entry>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final now = _clock();
      final entries = <String, _Entry>{};
      decoded.forEach((key, value) {
        final entry = _Entry.fromMap(Map<String, dynamic>.from(value as Map));
        // Prune anything older than the retention window on read.
        if (now.difference(entry.lastAlertAt) <= AppConstants.cooldownRetention) {
          entries[key] = entry;
        }
      });
      return entries;
    } catch (_) {
      return <String, _Entry>{};
    }
  }

  Future<void> _write(Map<String, _Entry> entries) => _store.setString(
        LocalKeys.alertCooldowns,
        jsonEncode(entries.map((k, v) => MapEntry(k, v.toMap()))),
      );

  static String _key(String userId, String cartId) => '$userId|$cartId';

  /// Cart ids that must not alert right now.
  Set<String> suppressedCartIds(String userId) {
    final now = _clock();
    final entries = _read();
    final suppressed = <String>{};

    for (final entry in entries.entries) {
      if (!entry.key.startsWith('$userId|')) continue;
      if (now.difference(entry.value.lastAlertAt) < AppConstants.proximityCooldown) {
        suppressed.add(entry.key.split('|').last);
      }
    }
    return suppressed;
  }

  /// True once the hourly cap is reached.
  bool hasHitHourlyCap(String userId) {
    final now = _clock();
    final recent = _read().entries.where((e) =>
        e.key.startsWith('$userId|') &&
        now.difference(e.value.lastAlertAt) < const Duration(hours: 1));
    return recent.length >= AppConstants.maxProximityAlertsPerHour;
  }

  Future<void> recordAlert({
    required String userId,
    required String cartId,
    required double distanceKm,
  }) async {
    final entries = _read();
    entries[_key(userId, cartId)] = _Entry(
      lastAlertAt: _clock(),
      lastDistanceKm: distanceKm,
    );
    await _write(entries);
  }

  /// Clears cooldowns for carts the user has now moved well away from.
  Future<void> applyExitResets({
    required String userId,
    required Map<String, double> observedDistancesKm,
    required double Function(String cartId) thresholdForCart,
  }) async {
    final entries = _read();
    var changed = false;

    for (final observed in observedDistancesKm.entries) {
      final key = _key(userId, observed.key);
      if (!entries.containsKey(key)) continue;

      final resetAt =
          thresholdForCart(observed.key) * AppConstants.cooldownResetMultiplier;
      if (observed.value > resetAt) {
        entries.remove(key);
        changed = true;
      }
    }

    if (changed) await _write(entries);
  }

  Future<void> clearForUser(String userId) async {
    final entries = _read()
      ..removeWhere((key, _) => key.startsWith('$userId|'));
    await _write(entries);
  }
}

class _Entry {
  const _Entry({required this.lastAlertAt, required this.lastDistanceKm});

  final DateTime lastAlertAt;
  final double lastDistanceKm;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'lastAlertAt': lastAlertAt.toIso8601String(),
        'lastDistanceKm': lastDistanceKm,
      };

  factory _Entry.fromMap(Map<String, dynamic> map) => _Entry(
        lastAlertAt: DateTime.tryParse(map['lastAlertAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        lastDistanceKm: (map['lastDistanceKm'] as num?)?.toDouble() ?? 0,
      );
}
