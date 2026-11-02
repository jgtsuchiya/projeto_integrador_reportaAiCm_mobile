import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/config/app_config.dart';
import 'package:reportaai_cm/core/config/app_config_provider.dart';
import 'package:reportaai_cm/core/network/api_log_interceptor.dart';
import 'package:reportaai_cm/core/network/dio_provider.dart';

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
  });

  group('dioProvider', () {
    test('deve criar um Dio único, com a configuração do app', () {
      final container = ProviderContainer.test(
        overrides: [appConfigProvider.overrideWithValue(testConfig)],
      );

      final sut = container.read(dioProvider);

      expect(sut.options.baseUrl, 'http://localhost:3000/api');
      expect(container.read(dioProvider), same(sut));
    });
  });
}
