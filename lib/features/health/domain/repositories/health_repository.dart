import 'package:reportaai_cm/features/health/domain/models/health_status.dart';

/// Confere se a API está no ar. A implementação que chama a API fica em `data/`, e os testes
/// usam um fake.
abstract interface class HealthRepository {
  /// Lança uma `ApiException` (de `core/network`) quando a API não responde ou responde com erro.
  Future<HealthStatus> check();
}
