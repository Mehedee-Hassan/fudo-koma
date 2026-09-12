/// System-notification surface. Swapped per platform and per backend so the
/// proximity pipeline never depends on a plugin directly.
abstract class NotificationGateway {
  Future<void> initialize();
  Future<bool> requestPermission();

  Future<void> show({
    required String id,
    required String title,
    required String body,
    String? deeplink,
  });

  /// Emits the deeplink of a tapped notification.
  Stream<String> get taps;

  void dispose();
}

/// Web and tests. `flutter_local_notifications` has no web implementation, so
/// web surfaces alerts as an in-app banner instead.
class NoopNotificationGateway implements NotificationGateway {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> show({
    required String id,
    required String title,
    required String body,
    String? deeplink,
  }) async {}

  @override
  Stream<String> get taps => const Stream<String>.empty();

  @override
  void dispose() {}
}
