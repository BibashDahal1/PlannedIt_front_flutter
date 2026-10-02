import 'package:latlong2/latlong.dart';

class MapConfig {
  MapConfig._();

  /// Swap for MapTiler/Stadia/self-hosted before launch:
  /// flutter run --dart-define=MAP_TILE_URL=https://.../{z}/{x}/{y}.png
  static const String tileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const String photonUrl = String.fromEnvironment(
    'PHOTON_URL',
    defaultValue: 'https://photon.komoot.io',
  );

  static const String userAgentPackageName = 'app.plannedit.plannedit_app';

  /// Used only when location permission is denied. Same coordinates as
  /// the examples in your API docs.
  static final LatLng fallbackCenter = LatLng(26.4525, 87.2718);
}
