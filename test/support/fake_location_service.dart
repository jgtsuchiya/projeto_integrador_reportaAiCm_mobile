import 'dart:async';

import 'package:reportaai_cm/core/location/location_service.dart';

/// Uma posição precisa no centro de Campo Mourão, dentro da área atendida pela API.
final campoMouraoPosition = DevicePosition(
  latitude: -24.045812,
  longitude: -52.378901,
  accuracyMeters: 8,
  isMocked: false,
  timestamp: DateTime.utc(2026, 11, 20, 14, 30),
);

/// A [campoMouraoPosition] com a [accuracyMeters] ou o [isMocked] trocados, como a posição
/// imprecisa de um lugar fechado ou a de um app de localização falsa.
DevicePosition campoMouraoPositionWith({double? accuracyMeters, bool? isMocked}) => DevicePosition(
  latitude: campoMouraoPosition.latitude,
  longitude: campoMouraoPosition.longitude,
  accuracyMeters: accuracyMeters ?? campoMouraoPosition.accuracyMeters,
  isMocked: isMocked ?? campoMouraoPosition.isMocked,
  timestamp: campoMouraoPosition.timestamp,
);

/// Fake do [LocationService], escrito à mão como os fakes dos repositórios. Começa com o GPS
/// ligado, a permissão dada e a [campoMouraoPosition]: cada teste troca o que precisa e confere
/// as chamadas feitas.
final class FakeLocationService implements LocationService {
  bool serviceEnabled = true;

  /// A permissão atual, que o `checkPermission` devolve.
  LocationPermissionStatus permission = LocationPermissionStatus.granted;

  /// A resposta do cidadão ao pedido da permissão. Vira a [permission] atual, como no aparelho.
  LocationPermissionStatus permissionAfterRequest = LocationPermissionStatus.granted;

  int requestPermissionCalls = 0;

  /// A posição da próxima leitura, quando não há [positionError] nem [positionPending].
  DevicePosition position = campoMouraoPosition;

  /// Lançado na próxima leitura da posição.
  LocationException? positionError;

  /// Enquanto não é completado, a leitura da posição fica pendente: é o "Buscando a localização".
  Completer<void>? positionPending;

  int positionCalls = 0;

  int openAppSettingsCalls = 0;

  int openLocationSettingsCalls = 0;

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermissionStatus> checkPermission() async => permission;

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    requestPermissionCalls++;
    return permission = permissionAfterRequest;
  }

  @override
  Future<DevicePosition> getCurrentPosition({
    Duration timeLimit = LocationService.defaultTimeLimit,
  }) async {
    positionCalls++;

    final pending = positionPending;
    if (pending != null) await pending.future;

    final error = positionError;
    if (error != null) throw error;

    return position;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCalls++;
    return true;
  }
}
