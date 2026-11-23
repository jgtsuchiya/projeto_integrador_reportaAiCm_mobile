import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/location/geolocator_location_service.dart';
import 'package:reportaai_cm/core/location/location_service_provider.dart';

void main() {
  group('locationServiceProvider', () {
    test('deve fornecer a implementação pelo geolocator', () {
      final container = ProviderContainer.test();

      expect(container.read(locationServiceProvider), isA<GeolocatorLocationService>());
    });
  });
}
