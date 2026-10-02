import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/config/map_config.dart';
import '../domain/place_result.dart';

/// Uses its own plain Dio on purpose: the app's main DioClient attaches
/// your JWT to requests, and that must never be sent to a third party.
class GeocodingService {
  GeocodingService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: MapConfig.photonUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          // Browsers forbid setting User-Agent, so only set it natively.
          headers: kIsWeb
              ? null
              : {
                  'User-Agent':
                      'PlannedIT/1.0 (${MapConfig.userAgentPackageName})',
                },
        ),
      );

  final Dio _dio;

  /// Free-text search for places, shops, areas. `near` softly biases
  /// results toward that point.
  Future<List<PlaceResult>> search(
    String query, {
    LatLng? near,
    int limit = 8,
  }) async {
    final response = await _dio.get(
      '/api/',
      queryParameters: {
        'q': query,
        'limit': limit,
        'lang': 'en',
        if (near != null) 'lat': near.latitude,
        if (near != null) 'lon': near.longitude,
      },
    );
    return _parse(response.data);
  }

  /// Nearest named feature within ~250 m of the point, or null.
  Future<PlaceResult?> reverse(LatLng point) async {
    final response = await _dio.get(
      '/reverse',
      queryParameters: {
        'lat': point.latitude,
        'lon': point.longitude,
        'lang': 'en',
        'radius': 0.25,
        'limit': 1,
      },
    );
    final results = _parse(response.data);
    return results.isEmpty ? null : results.first;
  }

  List<PlaceResult> _parse(dynamic data) {
    final json = data is String ? jsonDecode(data) : data;
    final features = json is Map ? json['features'] : null;
    if (features is! List) return const [];
    return features
        .map((f) => f is Map<String, dynamic> ? _parseFeature(f) : null)
        .whereType<PlaceResult>()
        .toList();
  }

  PlaceResult? _parseFeature(Map<String, dynamic> feature) {
    final geometry = feature['geometry'];
    final coords = geometry is Map ? geometry['coordinates'] : null;
    if (coords is! List || coords.length < 2) return null;

    final rawProps = feature['properties'];
    final props = rawProps is Map
        ? rawProps.cast<String, dynamic>()
        : <String, dynamic>{};

    final name = _clean(props['name']);
    final street = _clean(props['street']);
    final house = _clean(props['housenumber']);
    final streetLine = street == null
        ? null
        : (house == null ? street : '$house $street');

    final parts = <String>[];
    for (final part in [
      streetLine,
      _clean(props['locality']),
      _clean(props['district']),
      _clean(props['city']),
      _clean(props['state']),
    ]) {
      if (part != null && part != name && !parts.contains(part))
        parts.add(part);
    }

    return PlaceResult(
      name: name,
      address: parts.isEmpty ? null : parts.join(', '),
      latitude: (coords[1] as num).toDouble(), // GeoJSON order is [lon, lat]
      longitude: (coords[0] as num).toDouble(),
    );
  }

  String? _clean(dynamic value) {
    final s = value?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }
}
