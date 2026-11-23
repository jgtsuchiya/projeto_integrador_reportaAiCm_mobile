import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/account/data/repositories/api_sessions_repository.dart';

import '../../../../support/fake_http_adapter.dart';
import '../../../../support/fake_sessions_repository.dart';

/// A lista do exemplo do `FRONTEND.md` do backend, com uma sessão antiga sem o IP e o user agent.
const List<Map<String, Object?>> _sessionsJson = [
  {
    'id': 'sessao-deste-aparelho',
    'createdAt': '2026-11-20T12:30:00.000Z',
    'expiresAt': '2026-11-27T12:30:00.000Z',
    'ipAddress': '203.0.113.10',
    'userAgent': 'ReportaAiCm/0.1.0 (Android)',
    'current': true,
  },
  {
    'id': 'sessao-antiga',
    'createdAt': '2026-11-01T18:00:00.000Z',
    'expiresAt': '2026-11-08T18:00:00.000Z',
    'ipAddress': null,
    'userAgent': null,
    'current': false,
  },
];

void main() {
  group('ApiSessionsRepository', () {
    late FakeHttpAdapter adapter;
    late ApiSessionsRepository sut;

    setUp(() {
      adapter = FakeHttpAdapter();
      sut = ApiSessionsRepository(fakeDio(adapter));
    });

    group('list', () {
      test('deve chamar o GET /api/users/me/sessions e devolver os modelos', () async {
        adapter.reply(200, body: _sessionsJson);

        final result = await sut.list();

        expect(result, [currentSession, unknownSession]);
        expect(adapter.requests.single.method, 'GET');
        expect(adapter.requests.single.uri.path, '/api/users/me/sessions');
      });

      for (final (description, body) in [
        ('a resposta que não é uma lista', <String, Object?>{'items': _sessionsJson}),
        ('um item que não é um objeto', ['sessao']),
        (
          'um item sem o id',
          [
            {..._sessionsJson.first}..remove('id'),
          ],
        ),
        (
          'uma data fora do formato',
          [
            {..._sessionsJson.first, 'createdAt': 'ontem'},
          ],
        ),
      ]) {
        test('deve lançar a ServerException com $description', () async {
          adapter.reply(200, body: body);

          await expectLater(sut.list(), throwsA(isA<ServerException>()));
        });
      }

      test('deve lançar a NetworkException sem conexão', () async {
        adapter.failWith(DioExceptionType.connectionError);

        await expectLater(sut.list(), throwsA(isA<NetworkException>()));
      });
    });

    group('revoke', () {
      test('deve chamar o DELETE /api/users/me/sessions/:id, com o id codificado', () async {
        adapter.reply(204);

        await sut.revoke('sessao/1');

        expect(adapter.requests.single.method, 'DELETE');
        expect(adapter.requests.single.uri.path, '/api/users/me/sessions/sessao%2F1');
      });

      test('deve lançar a NotFoundException quando a sessão já tinha acabado', () async {
        adapter.reply(
          404,
          body: {'statusCode': 404, 'error': 'Not Found', 'message': 'Sessão não encontrada.'},
        );

        await expectLater(sut.revoke('sessao-antiga'), throwsA(isA<NotFoundException>()));
      });
    });

    group('revokeOthers', () {
      test('deve chamar o DELETE /api/users/me/sessions', () async {
        adapter.reply(204);

        await sut.revokeOthers();

        expect(adapter.requests.single.method, 'DELETE');
        expect(adapter.requests.single.uri.path, '/api/users/me/sessions');
      });
    });
  });
}
