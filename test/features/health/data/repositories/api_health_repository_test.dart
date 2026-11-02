import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/health/data/repositories/api_health_repository.dart';
import 'package:reportaai_cm/features/health/domain/models/health_status.dart';

import '../../../../support/fake_http_adapter.dart';

void main() {
  group('ApiHealthRepository', () {
    late FakeHttpAdapter adapter;
    late ApiHealthRepository sut;

    setUp(() {
      adapter = FakeHttpAdapter();
      sut = ApiHealthRepository(fakeDio(adapter));
    });

    test('deve chamar o GET /api/health e devolver o modelo', () async {
      adapter.reply(200, body: {'status': 'ok', 'timestamp': '2026-10-20T15:30:00.000Z'});

      final result = await sut.check();

      expect(result, HealthStatus(status: 'ok', checkedAt: DateTime.utc(2026, 10, 20, 15, 30)));
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.uri.path, '/api/health');
    });

    test('deve lançar NetworkException com a API desligada', () async {
      adapter.failWith(DioExceptionType.connectionError);

      await expectLater(sut.check(), throwsA(isA<NetworkException>()));
    });

    test('deve lançar ServerException com a resposta fora do formato', () async {
      adapter.reply(200, body: {'status': 'ok'});

      await expectLater(sut.check(), throwsA(isA<ServerException>()));
    });
  });
}
