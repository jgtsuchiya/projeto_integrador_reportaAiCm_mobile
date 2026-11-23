import 'package:meta/meta.dart';

/// Um ponto do mapa, em graus (WGS 84, o sistema do GPS).
///
/// O `toString` não mostra as coordenadas: elas nunca vão para o log (RM27).
@immutable
final class GeoPoint {
  const new({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint(***)';
}

/// Uma localização do aparelho: o ponto e a precisão em metros, como a API recebe e devolve.
@immutable
final class GeoLocation {
  const new({required this.latitude, required this.longitude, required this.accuracyMeters});

  final double latitude;
  final double longitude;

  /// O raio, em metros, em que o aparelho garante o ponto. A API o guarda arredondado para cima.
  final double accuracyMeters;

  GeoPoint get point => GeoPoint(latitude: latitude, longitude: longitude);

  @override
  bool operator ==(Object other) =>
      other is GeoLocation &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.accuracyMeters == accuracyMeters;

  @override
  int get hashCode => Object.hash(latitude, longitude, accuracyMeters);

  // Só a precisão: as coordenadas não vão para o log (RM27).
  @override
  String toString() => 'GeoLocation(***, accuracyMeters: $accuracyMeters)';
}
