import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/core/location/geolocator_location_service.dart';
import 'package:reportaai_cm/core/location/location_service.dart';

/// A localização do aparelho. Os testes a trocam pelo `FakeLocationService` com
/// `locationServiceProvider.overrideWithValue(...)`.
final locationServiceProvider = Provider<LocationService>((ref) => GeolocatorLocationService());
