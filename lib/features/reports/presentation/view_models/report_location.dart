import 'package:meta/meta.dart';
import 'package:reportaai_cm/core/location/location_service.dart';
import 'package:reportaai_cm/features/reports/domain/models/geo_location.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_limits.dart';

/// Em que pé está a localização do aparelho, na abertura do reporte (e no voto, no epic da
/// validação).
enum LocationStatus {
  /// Ainda não foi lida: ela é lida junto com a foto.
  idle,

  /// O aparelho está buscando a posição.
  capturing,

  /// A posição serve para o envio: precisa e de verdade.
  ready,

  /// A precisão é pior que 50 m: o envio fica bloqueado (RM21).
  inaccurate,

  /// A posição veio de um app de localização falsa: o envio fica bloqueado (RM21).
  mocked,

  /// A permissão ainda não foi pedida: a tela explica o porquê antes do pedido.
  permissionNeeded,

  /// O cidadão negou a permissão agora: a tela explica e pede de novo.
  permissionDenied,

  /// O cidadão negou para sempre: só as configurações do aparelho liberam.
  permissionDeniedForever,

  /// O GPS do aparelho está desligado.
  serviceDisabled,

  /// O aparelho não achou a posição a tempo, ou outro erro dele.
  failed;

  /// Se o envio pode seguir com a posição.
  bool get isReady => this == ready;
}

/// O resultado da leitura: o status e a posição, quando o aparelho a leu (inclusive a imprecisa,
/// para a tela mostrar a precisão).
@immutable
final class LocationReading {
  const new(this.status, {this.position});

  final LocationStatus status;
  final DevicePosition? position;

  /// A localização para a API, só com a posição lida.
  GeoLocation? get location => switch (position) {
    final position? => GeoLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracyMeters,
    ),
    null => null,
  };

  @override
  bool operator ==(Object other) =>
      other is LocationReading && other.status == status && other.position == position;

  @override
  int get hashCode => Object.hash(status, position);

  @override
  String toString() => 'LocationReading(${status.name}, $position)';
}

/// Lê a posição do aparelho com as regras da RM21: o GPS ligado, a permissão dada, a precisão de
/// até 50 m e a posição de verdade (sem app de localização falsa). Não pede a permissão: quem
/// ainda não a deu vê a explicação antes do pedido ([requestReportLocation]).
Future<LocationReading> readReportLocation(LocationService service) async {
  try {
    if (!await service.isServiceEnabled()) {
      return const LocationReading(LocationStatus.serviceDisabled);
    }

    switch (await service.checkPermission()) {
      case LocationPermissionStatus.denied:
        return const LocationReading(LocationStatus.permissionNeeded);
      case LocationPermissionStatus.deniedForever:
        return const LocationReading(LocationStatus.permissionDeniedForever);
      case LocationPermissionStatus.granted:
        break;
    }

    final position = await service.getCurrentPosition();
    if (position.isMocked) return LocationReading(LocationStatus.mocked, position: position);
    if (position.accuracyMeters > ReportLimits.maxAccuracyMeters) {
      return LocationReading(LocationStatus.inaccurate, position: position);
    }
    return LocationReading(LocationStatus.ready, position: position);
  } on LocationException catch (error) {
    return LocationReading(switch (error) {
      LocationServiceDisabledException() => LocationStatus.serviceDisabled,
      LocationPermissionDeniedException() => LocationStatus.permissionNeeded,
      LocationPermissionDeniedForeverException() => LocationStatus.permissionDeniedForever,
      LocationTimeoutException() || LocationUnavailableException() => LocationStatus.failed,
    });
  } on Object {
    // Um erro do sistema fora dos previstos: a tela mostra o "Atualizar localização".
    return const LocationReading(LocationStatus.failed);
  }
}

/// Pede a permissão, depois da explicação da tela, e lê a posição se o cidadão aceitar.
Future<LocationReading> requestReportLocation(LocationService service) async {
  final LocationPermissionStatus permission;
  try {
    permission = await service.requestPermission();
  } on Object {
    return const LocationReading(LocationStatus.failed);
  }

  return switch (permission) {
    LocationPermissionStatus.granted => await readReportLocation(service),
    LocationPermissionStatus.denied => const LocationReading(LocationStatus.permissionDenied),
    LocationPermissionStatus.deniedForever => const LocationReading(
      LocationStatus.permissionDeniedForever,
    ),
  };
}
