/// Build-time configuration, supplied with `--dart-define`.
///
/// Keeping tokens and the admin code out of source is deliberate:
/// `SETUP_FIREBASE.md` warns against committing keys, but nothing enforced it.
abstract final class AppConfig {
  /// `local` | `firebase` | `auto` (default).
  ///
  /// `local` forces on-device storage even when real Firebase options exist,
  /// which is what makes QA runs and CI reproducible.
  static const String backendOverride =
      String.fromEnvironment('FOLLO_BACKEND', defaultValue: 'auto');

  /// Mapbox access token. Empty falls back to OpenStreetMap tiles.
  static const String mapboxToken =
      String.fromEnvironment('MAPBOX_TOKEN', defaultValue: '');

  /// When non-empty, "Admin" becomes selectable at registration but only for
  /// someone who can type this code. Without it, admin is never self-service.
  static const String adminCode =
      String.fromEnvironment('ADMIN_CODE', defaultValue: '');

  static bool get adminSignupEnabled => adminCode.isNotEmpty;
}
