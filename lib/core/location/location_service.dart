import 'package:meta/meta.dart';

/// A permissão de localização do app, como o sistema responde.
enum LocationPermissionStatus {
  /// O app pode ler a localização (enquanto está aberto, ou sempre).
  granted,

  /// Ainda não foi pedida, ou o cidadão negou uma vez: o app pode pedir de novo.
  denied,

  /// O cidadão negou para sempre: só as configurações do aparelho liberam.
  deniedForever,
}

/// Uma posição lida do GPS do aparelho.
@immutable
final class DevicePosition {
  const new({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.isMocked,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;

  /// O raio, em metros, em que o aparelho garante a posição: quanto menor, melhor.
  final double accuracyMeters;

  /// Se a posição veio de um app de localização falsa (só o Android informa).
  final bool isMocked;

  final DateTime timestamp;

  @override
  bool operator ==(Object other) =>
      other is DevicePosition &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.accuracyMeters == accuracyMeters &&
      other.isMocked == isMocked &&
      other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(latitude, longitude, accuracyMeters, isMocked, timestamp);

  // As coordenadas não vão para o log (RM27): o texto mostra só a precisão.
  @override
  String toString() =>
      'DevicePosition(accuracyMeters: $accuracyMeters, isMocked: $isMocked, timestamp: $timestamp)';
}

/// O que impediu a leitura da posição.
sealed class LocationException implements Exception {
  const new();
}

/// O GPS (o serviço de localização do aparelho) está desligado.
final class LocationServiceDisabledException extends LocationException {
  const new();
}

/// O cidadão negou a permissão, e o app pode pedir de novo.
final class LocationPermissionDeniedException extends LocationException {
  const new();
}

/// O cidadão negou a permissão para sempre: só as configurações do aparelho liberam.
final class LocationPermissionDeniedForeverException extends LocationException {
  const new();
}

/// O aparelho não achou a posição dentro do tempo limite, como num lugar fechado.
final class LocationTimeoutException extends LocationException {
  const new();
}

/// Outro erro do aparelho, como o sistema sem suporte à localização.
final class LocationUnavailableException extends LocationException {
  const new([this.cause]);

  final Object? cause;
}

/// A localização do aparelho, como o `SessionManager` para a sessão: só o `core/location/`
/// conhece o pacote do GPS, e o resto do app depende deste contrato. Os testes usam o
/// `FakeLocationService`.
abstract interface class LocationService {
  /// Se o GPS do aparelho está ligado.
  Future<bool> isServiceEnabled();

  /// A permissão atual, sem perguntar ao cidadão.
  Future<LocationPermissionStatus> checkPermission();

  /// Pede a permissão ao cidadão, com a janela do sistema, e devolve a resposta. Com a permissão
  /// negada para sempre, o sistema não pergunta de novo e devolve o [LocationPermissionStatus]
  /// na hora.
  Future<LocationPermissionStatus> requestPermission();

  /// A posição atual, com a precisão alta, em até [timeLimit]. Lança uma [LocationException]:
  /// o GPS desligado, a permissão negada, o tempo esgotado ou outro erro do aparelho.
  Future<DevicePosition> getCurrentPosition({Duration timeLimit = defaultTimeLimit});

  /// Abre as configurações do app no aparelho, onde o cidadão libera a permissão negada para
  /// sempre. Devolve `false` se o sistema não abriu.
  Future<bool> openAppSettings();

  /// Abre as configurações de localização do aparelho, para ligar o GPS. Devolve `false` se o
  /// sistema não abriu.
  Future<bool> openLocationSettings();

  /// O tempo limite padrão da [getCurrentPosition]: em lugar aberto, o GPS costuma responder em
  /// poucos segundos.
  static const defaultTimeLimit = Duration(seconds: 20);
}
