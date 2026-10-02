import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/config/map_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/activity_location.dart';

/// Covers the worst-case error from the API's 2-decimal rounding
/// (about 0.75 km), so the real spot is always inside the circle.
const double approximateAreaRadiusMeters = 800;

class ActivityLocationMap extends StatelessWidget {
  final ActivityLocation location;
  const ActivityLocationMap({super.key, required this.location});

  @override
  Widget build(BuildContext context) {
    final point = LatLng(location.latitude, location.longitude);
    final exact = location.isExact;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 190,
            child: FlutterMap(
              // Rebuild if the location upgrades from approximate to exact.
              key: ValueKey('${point.latitude},${point.longitude},$exact'),
              options: MapOptions(
                initialCenter: point,
                initialZoom: exact ? 16 : 13.5,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: MapConfig.tileUrl,
                  userAgentPackageName: MapConfig.userAgentPackageName,
                ),
                if (!exact)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: point,
                        radius: approximateAreaRadiusMeters,
                        useRadiusInMeter: true,
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderColor: AppColors.primary.withValues(alpha: 0.5),
                        borderStrokeWidth: 1.5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    exact
                        ? Marker(
                            point: point,
                            width: 40,
                            height: 40,
                            alignment: Alignment
                                .topCenter, // pin tip sits on the point
                            child: const Icon(
                              Icons.location_on,
                              size: 40,
                              color: AppColors.danger,
                            ),
                          )
                        : Marker(
                            point: point,
                            width: 14,
                            height: 14,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
                const SimpleAttributionWidget(
                  source: Text('OpenStreetMap contributors'),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(
            exact
                ? 'Exact location'
                : 'Approximate area only. The exact spot is kept private.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
