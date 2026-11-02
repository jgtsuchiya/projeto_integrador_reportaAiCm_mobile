import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/network/api_error_mapper.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';

import '../../support/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = FakeHttpAdapter();
    dio = fakeDio(adapter);
  });

  /// O erro que o `callApi` lança para um `GET` com a resposta definida no adapter.
  Future<ApiException> errorOf() async {
    try {
      await callApi(() => dio.get<Object?>('/qualquer'));
    } on ApiException catch (error) {
      return error;
    }
    fail('A chamada deveria ter falhado.');
  }

  Map<String, Object?> appError(int statusCode, String message, [Object? details]) => {
    'statusCode': statusCode,
    'error': 'Erro',
    'message': message,
    'details': ?details,
  };

  group('toApiException (respostas da API)', () {
    test('deve converter o 400 em ValidationException, com os erros por campo', () async {
      adapter.reply(
        400,
        body: appError(400, 'Dados inválidos.', [
          {'field': 'cpf', 'message': 'CPF inválido.'},
          {'field': 'password', 'message': 'A senha deve ter de 8 a 128 caracteres.'},
        ]),
      );

      final sut = await errorOf() as ValidationException;

      expect(sut.message, 'Dados inválidos.');
      expect(sut.fieldErrors, const [
        FieldError(field: 'cpf', message: 'CPF inválido.'),
        FieldError(field: 'password', message: 'A senha deve ter de 8 a 128 caracteres.'),
      ]);
      expect(sut.messageFor('cpf'), 'CPF inválido.');
      expect(sut.messageFor('email'), isNull);
    });

    test('deve converter o 401 da aplicação em UnauthorizedException, com o campo', () async {
      adapter.reply(
        401,
        body: appError(401, 'Senha atual incorreta.', {'field': 'currentPassword'}),
      );

      final sut = await errorOf();

      expect(
        sut,
        isA<UnauthorizedException>()
            .having((error) => error.message, 'message', 'Senha atual incorreta.')
            .having((error) => error.field, 'field', 'currentPassword'),
      );
    });

    test('deve converter o 401 do SuperTokens com a mensagem do app, não a da API', () async {
      adapter.reply(401, body: {'message': 'unauthorised'});

      final sut = await errorOf();

      expect(sut, isA<UnauthorizedException>());
      expect(sut.message, UnauthorizedException.defaultMessage);
    });

    test('deve converter o 403 de permissão em ForbiddenException', () async {
      adapter.reply(403, body: appError(403, 'Operação não permitida.'));

      final sut = await errorOf();

      expect(sut, isA<ForbiddenException>());
      expect(sut.message, 'Operação não permitida.');
    });

    test('deve converter o 403 da sessão pendente em SecondFactorPendingException', () async {
      adapter.reply(
        403,
        body: {
          'message': 'invalid claim',
          'claimValidationErrors': [
            {
              'id': 'mfa-verified',
              'reason': {'message': 'wrong value', 'expectedValue': true, 'actualValue': false},
            },
          ],
        },
      );

      final sut = await errorOf();

      expect(sut, isA<SecondFactorPendingException>());
      expect(sut.message, SecondFactorPendingException.defaultMessage);
    });

    test('deve converter o 404 em NotFoundException', () async {
      adapter.reply(404, body: appError(404, 'Usuário não encontrado.'));

      final sut = await errorOf();

      expect(sut, isA<NotFoundException>());
      expect(sut.message, 'Usuário não encontrado.');
    });

    test('deve converter o 409 em ConflictException, com o campo', () async {
      adapter.reply(409, body: appError(409, 'E-mail já cadastrado.', {'field': 'email'}));

      final sut = await errorOf();

      expect(
        sut,
        isA<ConflictException>()
            .having((error) => error.message, 'message', 'E-mail já cadastrado.')
            .having((error) => error.field, 'field', 'email'),
      );
    });

    test('deve converter o 422 em BusinessRuleException', () async {
      adapter.reply(422, body: appError(422, 'Aguarde 1 minuto para pedir outro e-mail.'));

      final sut = await errorOf();

      expect(sut, isA<BusinessRuleException>());
      expect(sut.message, 'Aguarde 1 minuto para pedir outro e-mail.');
    });

    test('deve converter o 429 em RateLimitException, com o Retry-After', () async {
      adapter.reply(
        429,
        body: appError(429, 'Muitas requisições. Tente novamente em instantes.'),
        headers: {'retry-after': '42'},
      );

      final sut = await errorOf();

      expect(
        sut,
        isA<RateLimitException>()
            .having((error) => error.retryAfter, 'retryAfter', const Duration(seconds: 42))
            .having(
              (error) => error.message,
              'message',
              'Muitas requisições. Tente novamente em instantes.',
            ),
      );
    });

    test('deve converter o 429 sem o Retry-After, ou com ele inválido', () async {
      for (final headers in [
        <String, String>{},
        {'retry-after': 'amanhã'},
      ]) {
        adapter.reply(429, body: appError(429, 'Muitas requisições.'), headers: headers);

        final sut = await errorOf();

        expect(sut, isA<RateLimitException>().having((e) => e.retryAfter, 'retryAfter', isNull));
      }
    });

    test('deve converter o 5xx em ServerException, sempre com a mensagem padrão', () async {
      adapter.reply(500, body: appError(500, 'Erro interno do servidor.'));

      final sut = await errorOf();

      expect(sut, isA<ServerException>().having((e) => e.statusCode, 'statusCode', 500));
      expect(sut.message, ServerException.defaultMessage);
    });

    test('deve converter uma resposta fora do formato em ServerException', () async {
      adapter.replyText(502, '<html><body>Bad Gateway</body></html>');

      final sut = await errorOf();

      expect(sut, isA<ServerException>().having((e) => e.statusCode, 'statusCode', 502));
    });

    test('deve converter um status sem tratamento próprio em ServerException', () async {
      adapter.reply(418, body: appError(418, "I'm a teapot"));

      expect(await errorOf(), isA<ServerException>());
    });

    test('deve usar a mensagem padrão quando o corpo do erro não tem a message', () async {
      for (final reply in [
        () => adapter.replyText(400, 'Bad Request'),
        () => adapter.reply(400, body: {'statusCode': 400, 'error': 'Bad Request'}),
      ]) {
        reply();

        final sut = await errorOf() as ValidationException;

        expect(sut.message, ValidationException.defaultMessage);
        expect(sut.fieldErrors, isEmpty);
      }
    });
  });

  group('toApiException (sem resposta)', () {
    test('deve converter a falta de conexão em NetworkException', () async {
      adapter.failWith(DioExceptionType.connectionError);

      final sut = await errorOf();

      expect(sut, isA<NetworkException>().having((e) => e.isTimeout, 'isTimeout', isFalse));
      expect(sut.message, NetworkException.defaultMessage);
    });

    test('deve converter os timeouts em NetworkException', () async {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        adapter.failWith(type);

        expect(
          await errorOf(),
          isA<NetworkException>().having((e) => e.isTimeout, 'isTimeout', isTrue),
          reason: type.name,
        );
      }
    });

    test('deve converter o erro de socket do dart:io em NetworkException', () async {
      adapter.throwError(const SocketException('Connection refused'));

      expect(await errorOf(), isA<NetworkException>());
    });

    test('deve converter um erro desconhecido do Dio em ServerException', () async {
      adapter.throwError(const FormatException('falha no adapter'));

      expect(await errorOf(), isA<ServerException>());
    });
  });

  group('callApi', () {
    test('deve devolver o resultado da chamada', () async {
      adapter.reply(200, body: {'status': 'ok'});

      final sut = await callApi(() async {
        final response = await dio.get<Map<String, dynamic>>('/health');
        return response.data!['status'];
      });

      expect(sut, 'ok');
    });

    test('deve converter um erro inesperado em ServerException, sem derrubar o app', () async {
      adapter.reply(200, body: {'status': 42});

      final call = callApi(() async {
        final response = await dio.get<Map<String, dynamic>>('/health');
        return response.data!['status'] as String;
      });

      await expectLater(
        call,
        throwsA(
          isA<ServerException>()
              .having((e) => e.message, 'message', ServerException.defaultMessage)
              .having((e) => e.cause, 'cause', isA<TypeError>()),
        ),
      );
    });

    test('deve repassar uma ApiException sem mudar', () async {
      const error = ConflictException(field: 'cpf');

      await expectLater(callApi<void>(() => throw error), throwsA(same(error)));
    });

    test('deve usar a ApiException que um interceptor colocou no erro do Dio', () {
      const inner = SecondFactorPendingException();
      final error = DioException(requestOptions: RequestOptions(), error: inner);

      expect(toApiException(error), same(inner));
    });
  });

  group('ApiException.messageOf', () {
    test('deve devolver a mensagem da ApiException ou a padrão', () {
      expect(ApiException.messageOf(const NotFoundException(message: 'Sumiu.')), 'Sumiu.');
      expect(ApiException.messageOf(StateError('defeito')), ServerException.defaultMessage);
    });
  });
}
