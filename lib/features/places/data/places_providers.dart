import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/location/location_service.dart';
import 'geocoding_service.dart';

final locationServiceProvider = Provider((ref) => LocationService());
final geocodingServiceProvider = Provider((ref) => GeocodingService());
