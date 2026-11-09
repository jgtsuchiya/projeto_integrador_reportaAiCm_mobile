import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/auth/session_manager_provider.dart';
import 'package:reportaai_cm/core/config/app_config_provider.dart';
import 'package:reportaai_cm/features/auth/auth_providers.dart';
import 'package:reportaai_cm/features/auth/data/repositories/api_auth_repository.dart';

import '../../support/fake_session_manager.dart';
import '../../support/pump_app.dart';

void main() {
  group('authRepositoryProvider', () {
    test('deve ligar o contrato à implementação que chama a API', () {
      final container = ProviderContainer.test(
        overrides: [
          appConfigProvider.overrideWithValue(testConfig),
          sessionManagerProvider.overrideWithValue(FakeSessionManager()),
        ],
      );

      expect(container.read(authRepositoryProvider), isA<ApiAuthRepository>());
    });
  });
}
