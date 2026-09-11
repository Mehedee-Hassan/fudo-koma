class MapboxConfig {
  static const mapboxAccessToken = 'YOUR_MAPBOX_ACCESS_TOKEN';

  static bool get isConfigured =>
      mapboxAccessToken.trim().isNotEmpty &&
      mapboxAccessToken.trim() != 'YOUR_MAPBOX_ACCESS_TOKEN';

  static String buildStyleUrl() {
    return 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/256/{z}/{x}/{y}?access_token=$mapboxAccessToken';
  }

  static const mapboxStyleUrl =
      'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/256/{z}/{x}/{y}?access_token=YOUR_MAPBOX_ACCESS_TOKEN';
}
