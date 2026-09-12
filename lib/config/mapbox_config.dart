import '../core/app_config.dart';

/// Tile source configuration.
///
/// Now an instance class: the old static version made the access token a source
/// literal and pinned a test to the unconfigured branch, so the suite would
/// break the moment a real token was added.
class MapboxConfig {
  const MapboxConfig({this.accessToken = ''});

  /// Token from `--dart-define=MAPBOX_TOKEN=...`, so it stays out of source.
  factory MapboxConfig.fromEnvironment() =>
      const MapboxConfig(accessToken: AppConfig.mapboxToken);

  final String accessToken;

  static const String openStreetMapTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  bool get isConfigured =>
      accessToken.isNotEmpty && !accessToken.startsWith('YOUR_');

  /// 512 px @2x tiles on streets-v12; the previous streets-v11 at 256 px is
  /// deprecated and looked soft on retina screens.
  String buildStyleUrl() =>
      'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/512/{z}/{x}/{y}@2x'
      '?access_token=$accessToken';

  String get tileUrl => isConfigured ? buildStyleUrl() : openStreetMapTileUrl;

  /// Mapbox's 512 px tiles need these on the TileLayer to line up with the
  /// standard 256 px web-mercator grid.
  int get tileSize => isConfigured ? 512 : 256;
  double get zoomOffset => isConfigured ? -1 : 0;

  String get providerLabel =>
      isConfigured ? 'Mapbox streets' : 'OpenStreetMap contributors';
}
