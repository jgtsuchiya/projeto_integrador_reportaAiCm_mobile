import 'dart:async';

import 'package:geolocator/geolocator.dart' as geo;
import 'package:reportaai_cm/core/location/location_service.dart';

/// [LocationService] pelo pacote `geolocator`, o único lugar do app que o importa. A plataforma
/// é a do pacote (`GeolocatorPlatform.instance`), e os testes passam um fake no `platform`.
final class GeolocatorLocationService implements LocationService {
  new({geo.GeolocatorPlatform? platform}) : _platform = platform ?? geo.GeolocatorPlatform.instance;

  final geo.GeolocatorPlatform _platform;

  @override
  Future<bool> isServiceEnabled() => _platform.isLocationServiceEnabled();

  @override
  Future<LocationPermissionStatus> checkPermission() async =>
      _statusOf(await _platform.checkPermission());

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    try {
      return _statusOf(await _platform.requestPermission());
    } on geo.PermissionRequestInProgressException {
      // Outro pedido já está aberto na tela: a resposta dele vale para os dois.
      return LocationPermissionStatus.denied;
    }
  }

  @override
  Future<DevicePosition> getCurrentPosition({
    Duration timeLimit = LocationService.defaultTimeLimit,
  }) async {
    final geo.Position position;
    try {
      position = await _platform.getCurrentPosition(
        locationSettings: geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: timeLimit,
        ),
      );
    } on geo.LocationServiceDisabledException {
      throw const LocationServiceDisabledException();
    } on geo.PermissionDeniedException {
      // O pacote não diz se foi para sempre: a permissão atual diz.
      final permission = await _platform.checkPermission();
      throw permission == geo.LocationPermission.deniedForever
          ? const LocationPermissionDeniedForeverException()
          : const LocationPermissionDeniedException();
    } on TimeoutException {
      throw const LocationTimeoutException();
    } on Object catch (error) {
      throw LocationUnavailableException(error);
    }

    return DevicePosition(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      isMocked: position.isMocked,
      timestamp: position.timestamp,
    );
  }

  @override
  Future<bool> openAppSettings() => _platform.openAppSettings();

  @override
  Future<bool> openLocationSettings() => _platform.openLocationSettings();
}

/// O `unableToDetermine` (o navegador, sem resposta) fica como negada: o app pede de novo.
LocationPermissionStatus _statusOf(geo.LocationPermission permission) => switch (permission) {
  geo.LocationPermission.whileInUse ||
  geo.LocationPermission.always => LocationPermissionStatus.granted,
  geo.LocationPermission.deniedForever => LocationPermissionStatus.deniedForever,
  geo.LocationPermission.denied ||
  geo.LocationPermission.unableToDetermine => LocationPermissionStatus.denied,
};
