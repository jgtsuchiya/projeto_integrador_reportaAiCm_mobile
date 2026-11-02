import 'dart:async';

import 'package:reportaai_cm/features/health/domain/models/health_status.dart';
import 'package:reportaai_cm/features/health/domain/repositories/health_repository.dart';

final okHealthStatus = HealthStatus(status: 'ok', checkedAt: DateTime.utc(2026, 10, 20, 15, 30));

/// Fake do [HealthRepository], escrito à mão como o `FakeIdentityProvider` do backend. Cada teste
/// define o resultado da próxima chamada e confere quantas foram feitas em [calls].
final class FakeHealthRepository implements HealthRepository {
  /// Devolvido quando não há [error] nem [pending].
  HealthStatus result = okHealthStatus;

  /// Lançado na próxima chamada, como o repositório real lança as exceções da API.
  Exception? error;

  /// Enquanto não é completado, a chamada fica pendente: é o estado de carregando da tela.
  Completer<HealthStatus>? pending;

  int calls = 0;

  @override
  Future<HealthStatus> check() {
    calls++;

    final pending = this.pending;
    if (pending != null) return pending.future;

    final error = this.error;
    if (error != null) return Future.error(error);

    return Future.value(result);
  }
}
