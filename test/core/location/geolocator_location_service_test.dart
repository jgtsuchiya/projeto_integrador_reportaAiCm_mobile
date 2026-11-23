import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:reportaai_cm/core/location/geolocator_location_service.dart';
import 'package:reportaai_cm/core/location/location_service.dart'
    hide LocationServiceDisabledException;
import 'package:reportaai_cm/core/location/location_service.dart'
    as app
    show LocationServiceDisabledException;

/// O `geolocator` no lugar do aparelho: o teste define as respostas e confere os pedidos.
final class _FakeGeolocator extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission permissionAfterRequest = LocationPermission.whileInUse;
  Exception? positionError;
  final settings = <LocationSettings?>[];
  int appSettingsCalls = 0;
  int locationSettingsCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission = permissionAfterRequest;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    settings.add(locationSettings);
    if (positionError case final error?) throw error;

    return Position(
      latitude: -24.045812,
      longitude: -52.378901,
      timestamp: DateTime.utc(2026, 11, 20, 14, 30),
      accuracy: 8.5,
      altitude: 600,
      altitudeAccuracy: 3,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      isMocked: true,
    );
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsCalls++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsCalls++;
    return false;
  }
}

void main() {
  group('GeolocatorLocationService', () {
    late _FakeGeolocator geolocator;
    late GeolocatorLocationService sut;

    setUp(() {
      geolocator = _FakeGeolocator();
      sut = GeolocatorLocationService(platform: geolocator);
    });

    test('deve dizer se o GPS está ligado', () async {
      expect(await sut.isServiceEnabled(), isTrue);

      geolocator.serviceEnabled = false;

      expect(await sut.isServiceEnabled(), isFalse);
    });

    test('deve converter cada permissão do pacote', () async {
      const expected = {
        LocationPermission.whileInUse: LocationPermissionStatus.granted,
        LocationPermission.always: LocationPermissionStatus.granted,
        LocationPermission.denied: LocationPermissionStatus.denied,
        LocationPermission.unableToDetermine: LocationPermissionStatus.denied,
        LocationPermission.deniedForever: LocationPermissionStatus.deniedForever,
      };

      for (final MapEntry(key: permission, value: status) in expected.entries) {
        geolocator.permission = permission;

        expect(await sut.checkPermission(), status, reason: '$permission');
      }
    });

    test('deve pedir a permissão e devolver a resposta do cidadão', () async {
      geolocator
        ..permission = LocationPermission.denied
        ..permissionAfterRequest = LocationPermission.deniedForever;

      expect(await sut.requestPermission(), LocationPermissionStatus.deniedForever);
    });

    test('deve tratar o pedido que já está aberto na tela como negado', () async {
      final sut = GeolocatorLocationService(platform: _RequestInProgressGeolocator());

      expect(await sut.requestPermission(), LocationPermissionStatus.denied);
    });

    test('deve ler a posição com a precisão alta e o tempo limite de 20 s', () async {
      final position = await sut.getCurrentPosition();

      expect(
        position,
        DevicePosition(
          latitude: -24.045812,
          longitude: -52.378901,
          accuracyMeters: 8.5,
          isMocked: true,
          timestamp: DateTime.utc(2026, 11, 20, 14, 30),
        ),
      );
      final settings = geolocator.settings.single!;
      expect(settings.accuracy, LocationAccuracy.high);
      expect(settings.timeLimit, const Duration(seconds: 20));
    });

    test('deve usar o tempo limite pedido', () async {
      await sut.getCurrentPosition(timeLimit: const Duration(seconds: 5));

      expect(geolocator.settings.single!.timeLimit, const Duration(seconds: 5));
    });

    test('deve converter os erros do pacote nas exceções do app', () async {
      final cases = <Exception, Matcher>{
        const LocationServiceDisabledException(): isA<app.LocationServiceDisabledException>(),
        TimeoutException('sem resposta'): isA<LocationTimeoutException>(),
        const ActivityMissingException('sem a Activity'): isA<LocationUnavailableException>()
            .having((error) => error.cause, 'cause', isA<ActivityMissingException>()),
      };

      for (final MapEntry(key: error, value: matcher) in cases.entries) {
        geolocator.positionError = error;

        await expectLater(sut.getCurrentPosition(), throwsA(matcher), reason: '$error');
      }
    });

    test('deve dizer se a permissão foi negada uma vez ou para sempre', () async {
      geolocator
        ..positionError = const PermissionDeniedException('negada')
        ..permission = LocationPermission.denied;

      await expectLater(
        sut.getCurrentPosition(),
        throwsA(isA<LocationPermissionDeniedException>()),
      );

      geolocator.permission = LocationPermission.deniedForever;

      await expectLater(
        sut.getCurrentPosition(),
        throwsA(isA<LocationPermissionDeniedForeverException>()),
      );
    });

    test('deve abrir as configurações do app e as da localização', () async {
      expect(await sut.openAppSettings(), isTrue);
      expect(await sut.openLocationSettings(), isFalse);
      expect(geolocator.appSettingsCalls, 1);
      expect(geolocator.locationSettingsCalls, 1);
    });

    test('não deve mostrar as coordenadas no texto da posição (RM27)', () async {
      final text = (await sut.getCurrentPosition()).toString();

      expect(text, isNot(contains('24.04')));
      expect(text, isNot(contains('52.37')));
      expect(text, contains('accuracyMeters: 8.5'));
    });
  });
}

final class _RequestInProgressGeolocator extends GeolocatorPlatform {
  @override
  Future<LocationPermission> requestPermission() =>
      throw const PermissionRequestInProgressException('outro pedido aberto');
}
