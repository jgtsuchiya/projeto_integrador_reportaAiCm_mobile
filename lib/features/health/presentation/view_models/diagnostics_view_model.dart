import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/features/health/domain/models/health_status.dart';
import 'package:reportaai_cm/features/health/health_providers.dart';

/// Estado da tela de diagnóstico: carregando, o resultado do `GET /api/health` ou o erro.
final AsyncNotifierProvider<DiagnosticsViewModel, HealthStatus> diagnosticsViewModelProvider =
    AsyncNotifierProvider.autoDispose(DiagnosticsViewModel.new);

final class DiagnosticsViewModel extends AsyncNotifier<HealthStatus> {
  /// Confere a API assim que a tela abre.
  @override
  Future<HealthStatus> build() => ref.watch(healthRepositoryProvider).check();

  /// Confere de novo. Enquanto confere, o estado volta a carregando.
  void refresh() => ref.invalidateSelf();
}
