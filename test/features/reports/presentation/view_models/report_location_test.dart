import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/location/location_service.dart';
import 'package:reportaai_cm/features/reports/domain/models/geo_location.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_location.dart';

import '../../../../support/fake_location_service.dart';

void main() {
  group('readReportLocation', () {
    late FakeLocationService service;

    setUp(() => service = FakeLocationService());

    test('deve devolver a posição precisa, pronta para o envio', () async {
      final reading = await readReportLocation(service);

      expect(reading, LocationReading(LocationStatus.ready, position: campoMouraoPosition));
      expect(reading.status.isReady, isTrue);
      expect(
        reading.location,
        const GeoLocation(latitude: -24.045812, longitude: -52.378901, accuracyMeters: 8),
      );
    });

    test('deve aceitar a precisão de exatamente 50 m e bloquear a pior (RM21)', () async {
      service.position = campoMouraoPositionWith(accuracyMeters: 50);
      expect((await readReportLocation(service)).status, LocationStatus.ready);

      service.position = campoMouraoPositionWith(accuracyMeters: 50.1);
      final reading = await readReportLocation(service);

      expect(reading.status, LocationStatus.inaccurate);
      expect(reading.position?.accuracyMeters, 50.1);
    });

    test('deve bloquear a posição de um app de localização falsa (RM21)', () async {
      service.position = campoMouraoPositionWith(isMocked: true);

      expect((await readReportLocation(service)).status, LocationStatus.mocked);
    });

    test('deve avisar o GPS desligado sem pedir a posição', () async {
      service.serviceEnabled = false;

      expect((await readReportLocation(service)).status, LocationStatus.serviceDisabled);
      expect(service.positionCalls, 0);
    });

    test('não deve pedir a permissão sozinho: a tela explica antes', () async {
      service.permission = LocationPermissionStatus.denied;

      expect((await readReportLocation(service)).status, LocationStatus.permissionNeeded);
      expect(service.requestPermissionCalls, 0);

      service.permission = LocationPermissionStatus.deniedForever;

      expect((await readReportLocation(service)).status, LocationStatus.permissionDeniedForever);
    });

    test('deve converter os erros da leitura', () async {
      final cases = {
        const LocationServiceDisabledException(): LocationStatus.serviceDisabled,
        const LocationPermissionDeniedException(): LocationStatus.permissionNeeded,
        const LocationPermissionDeniedForeverException(): LocationStatus.permissionDeniedForever,
        const LocationTimeoutException(): LocationStatus.failed,
        const LocationUnavailableException(): LocationStatus.failed,
      };

      for (final MapEntry(key: error, value: status) in cases.entries) {
        service.positionError = error;

        expect((await readReportLocation(service)).status, status, reason: '$error');
      }
    });

    test('deve tratar um erro fora dos previstos como falha', () async {
      final reading = await readReportLocation(_ThrowingLocationService());

      expect(reading, const LocationReading(LocationStatus.failed));
      expect(reading.location, isNull);
    });
  });

  group('requestReportLocation', () {
    late FakeLocationService service;

    setUp(() => service = FakeLocationService()..permission = LocationPermissionStatus.denied);

    test('deve pedir a permissão e ler a posição quando o cidadão aceita', () async {
      final reading = await requestReportLocation(service);

      expect(service.requestPermissionCalls, 1);
      expect(reading.status, LocationStatus.ready);
    });

    test('deve dizer se o cidadão negou agora ou para sempre', () async {
      service.permissionAfterRequest = LocationPermissionStatus.denied;
      expect((await requestReportLocation(service)).status, LocationStatus.permissionDenied);

      service.permissionAfterRequest = LocationPermissionStatus.deniedForever;
      expect((await requestReportLocation(service)).status, LocationStatus.permissionDeniedForever);
      expect(service.positionCalls, 0);
    });

    test('deve tratar o erro do pedido como falha', () async {
      expect(
        (await requestReportLocation(_ThrowingLocationService())).status,
        LocationStatus.failed,
      );
    });
  });

  group('LocationReading', () {
    test('não deve mostrar as coordenadas no texto (RM27)', () {
      final reading = LocationReading(LocationStatus.ready, position: campoMouraoPosition);

      expect(reading.toString(), isNot(contains('24.04')));
      expect(reading.toString(), startsWith('LocationReading(ready'));
      expect(
        reading.hashCode,
        LocationReading(LocationStatus.ready, position: campoMouraoPosition).hashCode,
      );
    });
  });
}

/// Um sistema que falha com um erro que o `LocationService` não prevê.
final class _ThrowingLocationService implements LocationService {
  @override
  Future<bool> isServiceEnabled() => throw StateError('falha do sistema');

  @override
  Future<LocationPermissionStatus> checkPermission() => throw StateError('falha do sistema');

  @override
  Future<LocationPermissionStatus> requestPermission() => throw StateError('falha do sistema');

  @override
  Future<DevicePosition> getCurrentPosition({
    Duration timeLimit = LocationService.defaultTimeLimit,
  }) => throw StateError('falha do sistema');

  @override
  Future<bool> openAppSettings() => throw StateError('falha do sistema');

  @override
  Future<bool> openLocationSettings() => throw StateError('falha do sistema');
}
