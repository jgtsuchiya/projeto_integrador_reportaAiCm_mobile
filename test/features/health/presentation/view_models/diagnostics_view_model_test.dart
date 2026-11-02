import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/health/health_providers.dart';
import 'package:reportaai_cm/features/health/presentation/view_models/diagnostics_view_model.dart';

import '../../../../support/fake_health_repository.dart';

void main() {
  group('DiagnosticsViewModel', () {
    late FakeHealthRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeHealthRepository();
      container = ProviderContainer.test(
        overrides: [healthRepositoryProvider.overrideWithValue(repository)],
        retry: noAutomaticRetry,
      );
    });

    /// Abre a tela: o ViewModel confere a API. O provider é autoDispose, e o ouvinte o mantém
    /// vivo entre as leituras, como a tela aberta.
    Future<void> open() async {
      container.listen(diagnosticsViewModelProvider, (_, _) {});
      try {
        await container.read(diagnosticsViewModelProvider.future);
      } on ApiException {
        // O erro fica no estado, que o teste confere.
      }
    }

    test('deve conferir a API ao abrir e guardar o resultado', () async {
      await open();

      expect(container.read(diagnosticsViewModelProvider).value, okHealthStatus);
      expect(repository.calls, 1);
    });

    test('deve guardar o erro da API, sem repetir sozinho', () async {
      repository.error = const NetworkException();

      await open();

      expect(container.read(diagnosticsViewModelProvider).error, isA<NetworkException>());
      expect(repository.calls, 1);
    });

    test('deve conferir de novo no refresh, passando pelo carregando', () async {
      repository.error = const NetworkException();
      await open();
      repository.error = null;

      container.read(diagnosticsViewModelProvider.notifier).refresh();

      expect(container.read(diagnosticsViewModelProvider).isLoading, isTrue);
      expect(await container.read(diagnosticsViewModelProvider.future), okHealthStatus);
      expect(repository.calls, 2);
    });
  });
}
