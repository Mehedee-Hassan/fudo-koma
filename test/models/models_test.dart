import 'package:flutter_test/flutter_test.dart';
import 'package:follo_cart/config/mapbox_config.dart';
import 'package:follo_cart/core/firebase_bootstrap.dart';
import 'package:follo_cart/core/formatters.dart';
import 'package:follo_cart/models/follow_model.dart';
import 'package:follo_cart/models/notification_model.dart';
import 'package:follo_cart/models/report_model.dart';
import 'package:follo_cart/models/schedule_entry_model.dart';
import 'package:follo_cart/models/user_profile_model.dart';
import 'package:follo_cart/models/user_role.dart';
import 'package:follo_cart/theme/cart_palette.dart';

import '../support/fakes.dart';

void main() {
  group('enum wire codecs', () {
    test('round-trip known values', () {
      for (final role in UserRole.values) {
        expect(UserRole.fromWire(role.wire), role);
      }
      for (final type in NotificationType.values) {
        expect(NotificationType.fromWire(type.wire), type);
      }
      for (final status in ReportStatus.values) {
        expect(ReportStatus.fromWire(status.wire), status);
      }
    });

    test('unknown values fall back instead of throwing', () {
      // Forward compatibility: a document written by a newer client must not
      // break an older one.
      expect(NotificationType.fromWire('teleported'), NotificationType.system);
      expect(UserRole.fromWire('wizard'), UserRole.customer);
      expect(ReportReason.fromWire('nonsense'), ReportReason.other);
      expect(ReportStatus.fromWire(null), ReportStatus.open);
    });
  });

  group('FollowModel', () {
    test('defaults to the 5 km product radius, constructor and wire', () {
      final follow = FollowModel(
        id: 'f1',
        userId: 'u1',
        cartId: 'c1',
        followedAt: DateTime(2026),
      );
      expect(follow.proximityAlertKm, 5);

      // The fromMap fallback is the one that would silently keep old follows
      // on the wrong radius.
      final decoded = FollowModel.fromMap(<String, dynamic>{
        'userId': 'u1',
        'cartId': 'c1',
        'followedAt': DateTime(2026).toIso8601String(),
      }, 'f1');
      expect(decoded.proximityAlertKm, 5);
      expect(FollowModel.defaultMatchesAppRadius, isTrue);
    });

    test('composite id is deterministic', () {
      expect(FollowModel.idFor('u1', 'c1'), FollowModel.idFor('u1', 'c1'));
      expect(FollowModel.idFor('u1', 'c1'), isNot(FollowModel.idFor('u2', 'c1')));
    });
  });

  group('ScheduleEntry', () {
    test('coversNow matches a normal window', () {
      const entry = ScheduleEntry(
        id: 's1',
        weekday: DateTime.friday,
        openMinute: 11 * 60,
        closeMinute: 21 * 60,
      );

      expect(entry.coversNow(DateTime(2026, 9, 11, 14)), isTrue);
      expect(entry.coversNow(DateTime(2026, 9, 11, 9)), isFalse);
      // Same time, wrong weekday.
      expect(entry.coversNow(DateTime(2026, 9, 12, 14)), isFalse);
    });

    test('coversNow handles a window running past midnight', () {
      const entry = ScheduleEntry(
        id: 's1',
        weekday: DateTime.friday,
        openMinute: 22 * 60,
        closeMinute: 60,
      );

      expect(entry.coversNow(DateTime(2026, 9, 11, 23)), isTrue);
      expect(entry.coversNow(DateTime(2026, 9, 11, 0, 30)), isTrue);
      expect(entry.coversNow(DateTime(2026, 9, 11, 15)), isFalse);
    });

    test('an inactive entry never covers', () {
      const entry = ScheduleEntry(
        id: 's1',
        weekday: DateTime.friday,
        openMinute: 0,
        closeMinute: 1439,
        isActive: false,
      );
      expect(entry.coversNow(DateTime(2026, 9, 11, 12)), isFalse);
    });

    test('a one-off entry only covers its own date', () {
      final entry = ScheduleEntry(
        id: 's1',
        weekday: DateTime.friday,
        openMinute: 11 * 60,
        closeMinute: 21 * 60,
        specificDate: DateTime(2026, 9, 11),
      );

      expect(entry.coversNow(DateTime(2026, 9, 11, 14)), isTrue);
      expect(entry.coversNow(DateTime(2026, 9, 18, 14)), isFalse);
    });

    test('round-trips through the wire format', () {
      final entry = ScheduleEntry(
        id: 's1',
        weekday: DateTime.monday,
        openMinute: 690,
        closeMinute: 1290,
        locationLabel: 'Oak Street',
        latitude: 1.0,
        longitude: 2.0,
        specificDate: DateTime(2026, 9, 12),
      );
      expect(ScheduleEntry.fromMap(entry.toMap()), entry);
    });
  });

  group('FoodCartModel schedule summary', () {
    test('says open until when a window covers now', () {
      final cart = testCart(id: 'c1', scheduleEntries: <ScheduleEntry>[
        const ScheduleEntry(
          id: 's1',
          weekday: DateTime.friday,
          openMinute: 11 * 60,
          closeMinute: 21 * 60 + 30,
        ),
      ]);
      expect(cart.scheduleSummary(DateTime(2026, 9, 11, 14)),
          'Open until 9:30 PM');
    });

    test('says opens at for a later window today', () {
      final cart = testCart(id: 'c1', scheduleEntries: <ScheduleEntry>[
        const ScheduleEntry(
          id: 's1',
          weekday: DateTime.friday,
          openMinute: 17 * 60,
          closeMinute: 21 * 60,
        ),
      ]);
      expect(cart.scheduleSummary(DateTime(2026, 9, 11, 9)), 'Opens at 5:00 PM');
    });

    test('is honest when nothing is published', () {
      expect(testCart(id: 'c1').scheduleSummary(),
          'No schedule published yet');
    });
  });

  group('formatters', () {
    test('distance switches unit at one kilometre', () {
      expect(DistanceFormat.label(0.82), '820 m away');
      expect(DistanceFormat.label(2.64), '2.6 km away');
      expect(DistanceFormat.label(null), 'Distance unavailable');
    });

    test('times render in 12-hour form', () {
      expect(TimeOfDayFormat.fromMinutes(0), '12:00 AM');
      expect(TimeOfDayFormat.fromMinutes(690), '11:30 AM');
      expect(TimeOfDayFormat.fromMinutes(720), '12:00 PM');
      expect(TimeOfDayFormat.fromMinutes(1290), '9:30 PM');
    });

    test('relative time reads naturally', () {
      final now = DateTime(2026, 9, 11, 12);
      expect(RelativeTime.label(now, now: now), 'Just now');
      expect(
        RelativeTime.label(now.subtract(const Duration(minutes: 12)), now: now),
        '12 min ago',
      );
      expect(
        RelativeTime.label(now.subtract(const Duration(hours: 3)), now: now),
        '3 hours ago',
      );
      expect(
        RelativeTime.label(now.subtract(const Duration(days: 1)), now: now),
        'Yesterday',
      );
    });
  });

  group('CartPalette', () {
    test('keys colour off the category first', () {
      final tea = CartPalette.colorFor(id: 'x', category: 'Tea, coffee & bites');
      final chai = CartPalette.colorFor(id: 'y', category: 'Chai and snacks');
      expect(tea, chai);
    });

    test('is stable for the same id across calls', () {
      final a = CartPalette.colorFor(id: 'cart-42');
      final b = CartPalette.colorFor(id: 'cart-42');
      expect(a, b);
    });

    test('spreads different ids across the palette', () {
      final colors = <int>{
        for (var i = 0; i < 20; i++)
          CartPalette.colorFor(id: 'cart-$i').toARGB32(),
      };
      expect(colors.length, greaterThan(1));
    });
  });

  group('MapboxConfig', () {
    test('falls back to OpenStreetMap when unconfigured', () {
      const config = MapboxConfig();
      expect(config.isConfigured, isFalse);
      expect(config.tileUrl, MapboxConfig.openStreetMapTileUrl);
      expect(config.providerLabel, 'OpenStreetMap contributors');
      expect(config.tileSize, 256);
    });

    test('treats a template token as unconfigured', () {
      const config = MapboxConfig(accessToken: 'YOUR_MAPBOX_ACCESS_TOKEN');
      expect(config.isConfigured, isFalse);
    });

    test('uses Mapbox 512px tiles once a real token is present', () {
      // The old test pinned the unconfigured branch, so adding a real token
      // broke the suite. Both branches are asserted now.
      const config = MapboxConfig(accessToken: 'pk.realtoken123');
      expect(config.isConfigured, isTrue);
      expect(config.tileUrl, startsWith('https://api.mapbox.com/'));
      expect(config.tileUrl, contains('access_token=pk.realtoken123'));
      expect(config.tileUrl, contains('streets-v12'));
      expect(config.tileSize, 512);
      expect(config.zoomOffset, -1);
    });
  });

  group('firebase bootstrap placeholder detection', () {
    test('recognises the generated template values', () {
      expect(looksPlaceholder('REPLACE_WITH_YOUR_WEB_API_KEY'), isTrue);
      expect(looksPlaceholder('YOUR_FIREBASE_PROJECT_ID'), isTrue);
      expect(looksPlaceholder(''), isTrue);
      expect(looksPlaceholder('   '), isTrue);
      expect(looksPlaceholder(null), isTrue);
    });

    test('accepts realistic values', () {
      expect(looksPlaceholder('AIzaSyA1b2C3d4E5f6G7h8'), isFalse);
      expect(looksPlaceholder('1:1234567890:web:abcdef'), isFalse);
    });

    test('all four fields must look real', () {
      expect(
        optionsLookReal(
          apiKey: 'AIzaSyA1b2C3',
          appId: '1:123:web:abc',
          projectId: 'follo-cart-prod',
          messagingSenderId: '1234567890',
        ),
        isTrue,
      );
      expect(
        optionsLookReal(
          apiKey: 'AIzaSyA1b2C3',
          appId: '1:123:web:abc',
          projectId: 'REPLACE_WITH_YOUR_FIREBASE_PROJECT_ID',
          messagingSenderId: '1234567890',
        ),
        isFalse,
      );
    });
  });

  group('UserProfileModel', () {
    test('round-trips and computes initials', () {
      final user = testUser(id: 'u1', name: 'Maya Chowdhury');
      expect(user.initials, 'MC');
      expect(testUser(id: 'u2', name: 'Ada').initials, 'A');

      expect(UserProfileModel.fromMap(user.toMap(), user.id), user);
    });

    test('clearBlockDetails wipes the block fields', () {
      final blocked = testUser(id: 'u1').copyWith(
        isBlocked: true,
        blockedBy: 'admin-1',
        blockedReason: 'Spam',
        blockedAt: DateTime(2026),
      );
      final restored =
          blocked.copyWith(isBlocked: false, clearBlockDetails: true);

      expect(restored.blockedBy, isNull);
      expect(restored.blockedReason, isNull);
      expect(restored.blockedAt, isNull);
    });
  });
}
