import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/auth/session_manager_provider.dart';

import '../../support/fake_session_manager.dart';

void main() {
  group('sessionManagerProvider', () {
    test('deve devolver a sessão fornecida por override', () {
      final sessionManager = FakeSessionManager();
      final container = ProviderContainer.test(
        overrides: [sessionManagerProvider.overrideWithValue(sessionManager)],
      );

      expect(container.read(sessionManagerProvider), same(sessionManager));
    });

    test('deve falhar sem o override, em vez de usar um SDK sem inicializar', () {
      final container = ProviderContainer.test();

      expect(() => container.read(sessionManagerProvider), throwsA(anything));
    });
  });
}
