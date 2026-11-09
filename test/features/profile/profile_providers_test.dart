import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/config/app_config_provider.dart';
import 'package:reportaai_cm/features/profile/data/repositories/api_profile_repository.dart';
import 'package:reportaai_cm/features/profile/profile_providers.dart';

import '../../support/pump_app.dart';

void main() {
  group('profileRepositoryProvider', () {
    test('deve ligar o contrato à implementação que chama a API', () {
      final container = ProviderContainer.test(
        overrides: [appConfigProvider.overrideWithValue(testConfig)],
      );

      expect(container.read(profileRepositoryProvider), isA<ApiProfileRepository>());
    });
  });
}
