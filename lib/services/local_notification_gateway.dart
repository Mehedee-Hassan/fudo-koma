import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_gateway.dart';

class LocalNotificationGateway implements NotificationGateway {
  LocalNotificationGateway();

  static const String _channelId = 'follo_cart_alerts';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _taps = StreamController<String>.broadcast();

  bool _ready = false;

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<void> initialize() async {
    if (_ready) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // Requested explicitly later, at the moment the user turns alerts on,
        // rather than ambushing them during startup.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) _taps.add(payload);
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'Cart alerts',
            description:
                'Nearby carts you follow, plus opening and schedule changes.',
            importance: Importance.high,
          ),
        );

    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android 13+ requires a runtime POST_NOTIFICATIONS grant.
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return granted ?? true;
    }

    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return granted ?? false;
  }

  @override
  Future<void> show({
    required String id,
    required String title,
    required String body,
    String? deeplink,
  }) async {
    await initialize();
    await _plugin.show(
      id.hashCode & 0x7fffffff,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Cart alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: deeplink,
    );
  }

  @override
  void dispose() => _taps.close();
}
