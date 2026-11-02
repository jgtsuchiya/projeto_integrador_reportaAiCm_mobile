import 'package:meta/meta.dart';

/// Resultado do `GET /api/health`: a API está no ar e respondeu.
@immutable
final class HealthStatus {
  const new({required this.status, required this.checkedAt});

  /// O `status` que a API devolve. Hoje, sempre `ok`.
  final String status;

  /// Quando a API respondeu, pelo relógio dela.
  final DateTime checkedAt;

  bool get isOk => status == 'ok';

  @override
  bool operator ==(Object other) =>
      other is HealthStatus && other.status == status && other.checkedAt == checkedAt;

  @override
  int get hashCode => Object.hash(status, checkedAt);

  @override
  String toString() => 'HealthStatus(status: $status, checkedAt: $checkedAt)';
}
