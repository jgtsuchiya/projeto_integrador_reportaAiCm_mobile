import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/auth/session_interceptors.dart';
import 'package:reportaai_cm/core/config/app_config.dart';
import 'package:reportaai_cm/core/config/app_config_provider.dart';
import 'package:reportaai_cm/core/network/api_log_interceptor.dart';
import 'package:reportaai_cm/core/network/dio_provider.dart';
import 'package:supertokens_flutter/dio.dart';

import '../../support/fake_http_adapter.dart';
import '../../support/pump_app.dart';

void main() {
  group('createDio', () {
    test('deve usar a API_URL com o /api, JSON e os timeouts', () {
      final sut = createDio(AppConfig(apiUrl: 'http://10.0.2.2:3000'));

      expect(sut.options.baseUrl, 'http://10.0.2.2:3000/api');
      expect(sut.options.connectTimeout, const Duration(seconds: 10));
      expect(sut.options.receiveTimeout, const Duration(seconds: 15));
      expect(sut.options.contentType, Headers.jsonContentType);
      expect(sut.options.headers[Headers.acceptHeader], Headers.jsonContentType);
    });

    test('deve montar o endereço da rota a partir do caminho com barra', () async {
      final adapter = FakeHttpAdapter()..reply(200, body: {'status': 'ok'});

      await fakeDio(adapter).get<Object?>('/health');

      expect(adapter.requests.single.uri.toString(), 'http://localhost:3000/api/health');
    });

    test('deve registrar o log só quando pedido', () {
      expect(createDio(testConfig).interceptors.whereType<ApiLogInterceptor>(), isEmpty);
      expect(
        createDio(testConfig, logRequests: true).interceptors.whereType<ApiLogInterceptor>(),
        hasLength(1),
      );
    });

    test('deve registrar a sessão só quando pedido', () {
      expect(
        createDio(testConfig).interceptors.whereType<SuperTokensInterceptorWrapper>(),
        isEmpty,
      );
      expect(
        createDio(
          testConfig,
          withSession: true,
        ).interceptors.whereType<SuperTokensInterceptorWrapper>(),
        hasLength(1),
      );
    });

    test('deve registrar a sessão antes do log', () {
      final interceptors = createDio(testConfig, withSession: true, logRequests: true).interceptors;

      final session = interceptors.indexWhere((item) => item is SuperTokensInterceptorWrapper);
      final unauthorized = interceptors.indexWhere(
        (item) => item is UnauthorizedResponseInterceptor,
      );
      final log = interceptors.indexWhere((item) => item is ApiLogInterceptor);

      expect(session, lessThan(unauthorized));
      expect(unauthorized, lessThan(log));
    });
  });

  group('dioProvider', () {
    test('deve criar um Dio único, com a configuração do app e a sessão', () {
      final container = ProviderContainer.test(
        overrides: [appConfigProvider.overrideWithValue(testConfig)],
      );

      final sut = container.read(dioProvider);

      expect(sut.options.baseUrl, 'http://localhost:3000/api');
      expect(sut.interceptors.whereType<SuperTokensInterceptorWrapper>(), hasLength(1));
      expect(container.read(dioProvider), same(sut));
    });
  });
}
