import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/config/app_config_provider.dart';

import '../../support/pump_app.dart';

void main() {
  group('appConfigProvider', () {
    test('deve devolver a configuração fornecida por override', () {
      final container = ProviderContainer.test(
        overrides: [appConfigProvider.overrideWithValue(testConfig)],
      );

      expect(container.read(appConfigProvider), testConfig);
    });

    test('deve falhar sem o override, em vez de usar um endereço padrão', () {
      final container = ProviderContainer.test();

      expect(() => container.read(appConfigProvider), throwsA(anything));
    });
  });
}
