import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/config/app_config_provider.dart';
import 'package:reportaai_cm/features/account/account_providers.dart';
import 'package:reportaai_cm/features/account/data/repositories/api_sessions_repository.dart';

import '../../support/pump_app.dart';

void main() {
  test('o sessionsRepositoryProvider deve usar a implementação da API', () {
    final container = ProviderContainer.test(
      overrides: [appConfigProvider.overrideWithValue(testConfig)],
    );

    expect(container.read(sessionsRepositoryProvider), isA<ApiSessionsRepository>());
  });
}
