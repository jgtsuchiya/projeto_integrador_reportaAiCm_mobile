import 'package:reportaai_cm/features/health/domain/models/health_status.dart';

/// O JSON do `GET /api/health`: `{ "status": "ok", "timestamp": "2026-10-20T12:00:00.000Z" }`.
final class HealthStatusDto {
  const new({required this.status, required this.timestamp});

  /// Lança uma [FormatException] quando o JSON não tem o formato esperado. O `callApi` a converte
  /// em `ServerException`.
  factory fromJson(Object? json) {
    if (json case {'status': final String status, 'timestamp': final String timestamp}) {
      final parsedTimestamp = DateTime.tryParse(timestamp);
      if (parsedTimestamp != null) {
        return HealthStatusDto(status: status, timestamp: parsedTimestamp);
      }
    }

    throw const FormatException('A resposta do GET /api/health está fora do formato esperado.');
  }

  final String status;
  final DateTime timestamp;

  HealthStatus toModel() => HealthStatus(status: status, checkedAt: timestamp);
}
