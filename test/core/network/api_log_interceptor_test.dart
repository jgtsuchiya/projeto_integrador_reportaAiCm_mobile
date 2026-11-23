import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/network/api_log_interceptor.dart';

import '../../support/fake_http_adapter.dart';

void main() {
  group('ApiLogInterceptor', () {
    late FakeHttpAdapter adapter;
    late Dio dio;
    late List<String> lines;

    String log() => lines.join('\n');

    setUp(() {
      adapter = FakeHttpAdapter();
      lines = [];
      dio = fakeDio(adapter)..interceptors.add(ApiLogInterceptor(log: lines.add));
    });

    test('deve registrar o método, o endereço, o status e o tempo', () async {
      adapter.reply(200, body: {'status': 'ok'});

      await dio.get<Object?>('/health');

      expect(lines, hasLength(2));
      expect(lines.first, startsWith('→ GET http://localhost:3000/api/health'));
      expect(lines.last, startsWith('← 200 GET http://localhost:3000/api/health ('));
      expect(lines.last, contains('{"status":"ok"}'));
    });

    test('não deve mostrar nenhum token da sessão, na ida e na volta', () async {
      adapter.reply(
        200,
        body: {'status': 'OK'},
        headers: {
          'st-access-token': 'novo-access-token',
          'st-refresh-token': 'novo-refresh-token',
          'front-token': 'novo-front-token',
          'anti-csrf': 'novo-anti-csrf',
          'set-cookie': 'sAccessToken=cookie-secreto',
        },
      );

      await dio.get<Object?>(
        '/users/me',
        options: Options(
          headers: {
            'Authorization': 'Bearer access-token-atual',
            'st-refresh-token': 'refresh-token-atual',
            'Cookie': 'sRefreshToken=cookie-atual',
          },
        ),
      );

      for (final secret in [
        'access-token-atual',
        'refresh-token-atual',
        'cookie-atual',
        'novo-access-token',
        'novo-refresh-token',
        'novo-front-token',
        'novo-anti-csrf',
        'cookie-secreto',
      ]) {
        expect(log(), isNot(contains(secret)), reason: secret);
      }
      expect(log(), contains('st-access-token: ***'));
    });

    test('não deve mostrar a senha nem o CPF do cadastro, na ida e na volta (RM09)', () async {
      adapter.reply(
        201,
        body: {'id': 'id-do-client', 'name': 'Maria da Silva', 'cpf': '52998224725'},
      );

      await dio.post<Object?>(
        '/clients',
        data: {
          'name': 'Maria da Silva',
          'email': 'maria.silva@exemplo.com',
          'password': 'senha-forte-1',
          'cpf': '52998224725',
          'phone': '44999998888',
          'birthDate': '1990-05-20',
        },
      );

      expect(log(), isNot(contains('senha-forte-1')));
      expect(log(), isNot(contains('52998224725')));
      expect(log(), contains('"password":"***"'));
      expect(log(), contains('"cpf":"***"'));
      expect(log(), contains('Maria da Silva'));
    });

    test('não deve mostrar o corpo das rotas de /auth', () async {
      adapter.reply(
        200,
        body: {
          'status': 'OK',
          'user': {'id': 'id-do-usuario'},
        },
      );

      await dio.post<Object?>(
        '/auth/signin',
        data: {
          'formFields': [
            {'id': 'email', 'value': 'maria@example.com'},
            {'id': 'password', 'value': 'SenhaSecreta123'},
          ],
        },
      );

      expect(log(), isNot(contains('SenhaSecreta123')));
      expect(log(), isNot(contains('maria@example.com')));
      expect(log(), isNot(contains('id-do-usuario')));
      expect(log(), contains('(omitido nas rotas de /api/auth)'));
    });

    test('deve mascarar a senha, o token, o código e o CPF dos outros corpos', () async {
      adapter.reply(200, body: {'name': 'Maria', 'cpf': '52998224725'});

      await dio.post<Object?>(
        '/clients',
        data: {
          'name': 'Maria',
          'cpf': '52998224725',
          'password': 'SenhaSecreta123',
          'nested': {'token': 'token-do-link', 'code': '123456'},
        },
      );

      for (final secret in ['52998224725', 'SenhaSecreta123', 'token-do-link', '123456']) {
        expect(log(), isNot(contains(secret)), reason: secret);
      }
      expect(log(), contains('"name":"Maria"'));
    });

    test('não deve mostrar o IP nem o user agent da lista de sessões abertas', () async {
      adapter.reply(
        200,
        body: [
          {
            'id': 'sessao-1',
            'createdAt': '2026-10-06T12:00:00.000Z',
            'ipAddress': '203.0.113.10',
            'userAgent': 'Mozilla/5.0 (X11; Linux x86_64)',
            'current': true,
          },
        ],
      );

      await dio.get<Object?>('/users/me/sessions');

      expect(log(), isNot(contains('203.0.113.10')));
      expect(log(), isNot(contains('Mozilla')));
      expect(log(), contains('"id":"sessao-1"'));
    });

    test('deve mascarar o token na query', () async {
      adapter.reply(204);

      await dio.get<Object?>('/email-verifications', queryParameters: {'token': 'token-do-link'});

      expect(log(), isNot(contains('token-do-link')));
      expect(log(), contains('token=***'));
    });

    test('deve registrar o erro, sem mostrar os tokens', () async {
      adapter.reply(401, body: {'message': 'unauthorised'});

      await expectLater(
        dio.get<Object?>(
          '/users/me',
          options: Options(headers: {'authorization': 'Bearer token-vencido'}),
        ),
        throwsA(isA<DioException>()),
      );

      expect(lines.last, startsWith('✖ 401 GET http://localhost:3000/api/users/me'));
      expect(log(), isNot(contains('token-vencido')));
    });

    test('deve registrar a falha sem resposta pelo tipo', () async {
      adapter.failWith(DioExceptionType.connectionError);

      await expectLater(dio.get<Object?>('/health'), throwsA(isA<DioException>()));

      expect(lines.last, startsWith('✖ connectionError GET'));
    });

    test('deve resumir o corpo que não é JSON', () async {
      adapter.replyText(502, '<html>Bad Gateway</html>');

      await expectLater(dio.get<Object?>('/health'), throwsA(isA<DioException>()));

      expect(lines.last, contains('(texto com 24 caracteres)'));
    });

    test('não deve mostrar a foto, a miniatura nem as coordenadas do reporte (RM27)', () async {
      final photo = 'A' * (512 * 1024);
      final thumbnail = 'B' * 2000;
      adapter.reply(
        201,
        body: {
          'id': 'reporte-1',
          'location': {'latitude': -24.045812, 'longitude': -52.378901, 'accuracyMeters': 9},
        },
      );

      // Como o repositório envia: o JSON já codificado, fora da thread da tela.
      await dio.post<Object?>(
        '/reports',
        data: jsonEncode({
          'description': 'Perto do semáforo',
          'location': {'latitude': -24.045812, 'longitude': -52.378901, 'accuracyMeters': 8.5},
          'photo': {'content': photo, 'thumbnail': thumbnail},
        }),
      );

      expect(log(), isNot(contains('AAAA')));
      expect(log(), isNot(contains('BBBB')));
      expect(log(), isNot(contains('24.04')));
      expect(log(), isNot(contains('52.37')));
      expect(log(), isNot(contains('8.5')));
      expect(log(), contains('"content":"*** (512 KB)"'));
      expect(log(), contains('"thumbnail":"*** (2 KB)"'));
      expect(log(), contains('"latitude":"***"'));
      expect(log(), contains('"accuracyMeters":"***"'));
      expect(log(), contains('Perto do semáforo'));
    });

    test('não deve mostrar a imagem da resposta da foto', () async {
      adapter.reply(
        200,
        body: {'id': 'foto-1', 'mimeType': 'image/jpeg', 'content': '/9j/${'C' * 3000}'},
      );

      await dio.get<Object?>('/reports/reporte-1/photo', queryParameters: {'size': 'full'});

      expect(log(), isNot(contains('CCCC')));
      expect(log(), contains('"content":"*** (3 KB)"'));
      expect(log(), contains('size=full'));
    });

    test('deve mascarar as coordenadas na query dos reportes perto', () async {
      adapter.reply(200, body: {'items': <Object?>[]});

      await dio.get<Object?>(
        '/reports/nearby',
        queryParameters: {'latitude': -24.045812, 'longitude': -52.378901, 'radiusMeters': 30},
      );

      expect(log(), isNot(contains('24.04')));
      expect(log(), isNot(contains('52.37')));
      expect(lines.first, contains('latitude=***&longitude=***&radiusMeters=30'));
    });
  });
}
