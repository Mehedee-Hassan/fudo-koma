import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follo_cart/app.dart';
import 'package:follo_cart/repositories/repository_bundle.dart';
import 'package:follo_cart/services/alert_cooldown_store.dart';
import 'package:follo_cart/services/notification_gateway.dart';
import 'package:follo_cart/repositories/local/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// Serves a 1x1 transparent PNG for every tile.
///
/// Without this, `TileLayer` fires real network requests that flutter_test's
/// mock HTTP client answers with 400s - noisy output and flaky timing.
class FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_transparentPixel);
}

final Uint8List _transparentPixel = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Future<LocalStore> testStore() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return LocalStore(await SharedPreferences.getInstance());
}

/// Boots the real app against fake repositories and a fake location service.
Future<void> pumpApp(
  WidgetTester tester, {
  required RepositoryBundle bundle,
  FakeLocationService? location,
  RecordingNotificationGateway? notifications,
  LocalStore? store,
}) async {
  final localStore = store ?? await testStore();

  await tester.pumpWidget(FolloCartApp(
    bundle: bundle,
    locationService: location ?? FakeLocationService(),
    notifications: notifications ?? RecordingNotificationGateway(),
    cooldowns: AlertCooldownStore(localStore),
    store: localStore,
    tileProvider: FakeTileProvider(),
  ));
  await tester.pump();
}

NotificationGateway noopGateway() => NoopNotificationGateway();
