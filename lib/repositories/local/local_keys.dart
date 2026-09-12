abstract final class LocalKeys {
  static const String prefix = 'follo_cart.v1';

  static const String schemaVersion = '$prefix.schemaVersion';
  /// Bumped to 2 when the demo account emails were shortened. `migrate()`
  /// clears and reseeds on a bump, so an install that already has the old
  /// accounts picks up the new ones instead of silently keeping stale logins.
  static const int currentSchemaVersion = 2;

  static const String users = '$prefix.users';
  static const String carts = '$prefix.carts';
  static const String follows = '$prefix.follows';
  static const String notifications = '$prefix.notifications';
  static const String cartUpdates = '$prefix.cartUpdates';
  static const String reports = '$prefix.reports';

  /// Scalars, not collections.
  static const String session = '$prefix.session';
  static const String guestMode = '$prefix.guestMode';
  static const String alertCooldowns = '$prefix.alertCooldowns';
  static const String backgroundAlerts = '$prefix.backgroundAlerts';
  static const String broadcasting = '$prefix.broadcasting';
}
