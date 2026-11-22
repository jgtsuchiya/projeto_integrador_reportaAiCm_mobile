import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/auth/supertokens_session_manager.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/core/network/dio_provider.dart';
import 'package:reportaai_cm/features/auth/data/repositories/api_auth_repository.dart';
import 'package:reportaai_cm/features/auth/domain/models/sign_in_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/fake_http_adapter.dart';
import '../../../../support/fake_session_api.dart';
import '../../../../support/fake_session_manager.dart';
import '../../../../support/pump_app.dart';

const _email = 'maria.silva@exemplo.com';
const _password = 'SenhaSecreta123';

void main() {
  group('ApiAuthRepository', () {
    late FakeHttpAdapter adapter;
    late FakeSessionManager session;
    late ApiAuthRepository sut;

    setUp(() {
      adapter = FakeHttpAdapter();
      session = FakeSessionManager();
      sut = ApiAuthRepository(fakeDio(adapter), session);
    });

    Future<SignInResult> signIn({String email = _email}) =>
        sut.signIn(email: email, password: _password);

    group('signIn', () {
      test('deve chamar o POST /api/auth/signin no formato do SuperTokens', () async {
        adapter.reply(200, body: {'status': 'OK'});

        final result = await signIn(email: ' Maria.Silva@Exemplo.com ');

        expect(result, const SignInSuccess());
        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/auth/signin');
        expect(request.data, {
          'formFields': [
            {'id': 'email', 'value': _email},
            {'id': 'password', 'value': _password},
          ],
        });
      });

      test('deve devolver o SignInWrongCredentials na senha errada (RM02)', () async {
        adapter.reply(200, body: {'status': 'WRONG_CREDENTIALS_ERROR'});

        expect(await signIn(), const SignInWrongCredentials());
      });

      test('deve devolver o SignInFieldError com a mensagem do app', () async {
        adapter.reply(
          200,
          body: {
            'status': 'FIELD_ERROR',
            'formFields': [
              {'id': 'email', 'error': 'Email is invalid'},
            ],
          },
        );

        expect(
          await signIn(),
          const SignInFieldError({SignInField.email: SignInFieldError.emailInvalidMessage}),
        );
      });

      test('deve devolver o SignInLocked com a message da API no bloqueio (RM03)', () async {
        const message = 'Muitas tentativas. Tente novamente em alguns minutos.';
        adapter.reply(200, body: {'status': 'GENERAL_ERROR', 'message': message});

        expect(await signIn(), const SignInLocked(message));
      });

      test('deve devolver o SignInRateLimited com o Retry-After do 429 (RM04)', () async {
        adapter.reply(
          429,
          body: {
            'statusCode': 429,
            'error': 'Too Many Requests',
            'message': 'Muitas requisições. Tente novamente em instantes.',
          },
          headers: {'retry-after': '42'},
        );

        expect(await signIn(), const SignInRateLimited(retryAfter: Duration(seconds: 42)));
      });

      test('deve esperar a janela inteira do limite no 429 sem o Retry-After', () async {
        adapter.reply(429, body: {'statusCode': 429, 'message': 'Muitas requisições.'});

        expect(
          await signIn(),
          const SignInRateLimited(retryAfter: SignInRateLimited.defaultRetryAfter),
        );
      });

      test('deve lançar a NetworkException sem conexão e no timeout', () async {
        for (final type in [
          DioExceptionType.connectionError,
          DioExceptionType.connectionTimeout,
          DioExceptionType.receiveTimeout,
        ]) {
          adapter.failWith(type);

          await expectLater(signIn(), throwsA(isA<NetworkException>()), reason: type.name);
        }
      });

      test('deve lançar a ServerException no 5xx', () async {
        adapter.reply(500, body: {'statusCode': 500, 'message': 'Erro interno do servidor.'});

        await expectLater(
          signIn(),
          throwsA(isA<ServerException>().having((e) => e.statusCode, 'statusCode', 500)),
        );
      });

      test('deve lançar a ServerException numa resposta que o app não conhece', () async {
        for (final reply in [
          () => adapter.reply(200, body: {'status': 'SIGN_IN_NOT_ALLOWED'}),
          () => adapter.replyText(200, '<html>Portal da rede Wi-Fi</html>'),
          // A API_URL apontando para outro servidor, ou o corpo recusado pelo SuperTokens.
          () => adapter.reply(404, body: {'statusCode': 404, 'message': 'Cannot POST'}),
          () => adapter.reply(400, body: {'message': 'formFields must be an array'}),
        ]) {
          reply();

          await expectLater(
            signIn(),
            throwsA(
              isA<ServerException>().having(
                (e) => e.message,
                'message',
                ServerException.defaultMessage,
              ),
            ),
          );
        }
      });
    });

    group('senha fora do log e das mensagens (RM09)', () {
      late List<String> logs;

      setUp(() {
        logs = [];
        final originalDebugPrint = debugPrint;
        debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
        addTearDown(() => debugPrint = originalDebugPrint);

        // O Dio com o log de debug, como o do app.
        sut = ApiAuthRepository(
          createDio(testConfig, logRequests: true)..httpClientAdapter = adapter,
          session,
        );
      });

      test('não deve mostrar a senha no log nem nas exceções', () async {
        final errors = <Object>[];
        for (final reply in [
          () => adapter.reply(200, body: {'status': 'OK'}),
          () => adapter.reply(200, body: {'status': 'WRONG_CREDENTIALS_ERROR'}),
          () => adapter.reply(500, body: {'statusCode': 500}),
          () => adapter.reply(404, body: {'statusCode': 404, 'message': 'Cannot POST'}),
          () => adapter.reply(200, body: {'status': 'DESCONHECIDO'}),
          () => adapter.failWith(DioExceptionType.connectionError),
          () => adapter.throwError(const FormatException('falha no adapter')),
        ]) {
          reply();
          try {
            await signIn();
          } on ApiException catch (error) {
            errors.add(error);
          }
        }

        expect(logs, isNotEmpty);
        expect(logs, everyElement(isNot(contains(_password))));
        expect(errors, hasLength(5));
        for (final error in errors) {
          final cause = error is ServerException ? error.cause : null;
          expect('$error $cause', isNot(contains(_password)));
        }
      });
    });

    group('sessão', () {
      test('deve repassar o hasSession e o isSecondFactorPending do SessionManager', () async {
        session
          ..hasStoredSession = true
          ..secondFactorPending = true;

        expect(await sut.hasSession(), isTrue);
        expect(await sut.isSecondFactorPending(), isTrue);
      });

      test('deve repassar as exceções do isSecondFactorPending', () async {
        for (final error in [const UnauthorizedException(), const NetworkException()]) {
          session.secondFactorError = error;

          await expectLater(sut.isSecondFactorPending(), throwsA(same(error)));
        }
      });

      test('deve encerrar a sessão pelo SessionManager', () async {
        session.hasStoredSession = true;

        await sut.signOut();

        expect(session.signOutCalls, 1);
        expect(await sut.hasSession(), isFalse);
      });

      test('deve manter a sessão quando o signOut fica sem conexão (RM10)', () async {
        session
          ..hasStoredSession = true
          ..signOutError = const NetworkException();

        await expectLater(sut.signOut(), throwsA(isA<NetworkException>()));

        expect(await sut.hasSession(), isTrue);
      });
    });
  });

  group('ApiAuthRepository com o SDK do SuperTokens', () {
    late SuperTokensSessionManager sessionManager;
    late FakeSessionApi api;
    late ApiAuthRepository sut;

    setUpAll(() {
      sessionManager = FakeSessionApi.initialize();
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      api = FakeSessionApi();
      sut = ApiAuthRepository(api.dio, sessionManager);
    });

    tearDown(() => api.endSession());

    test('deve guardar a sessão que volta nos headers do login', () async {
      api.adapter.reply(
        200,
        body: {'status': 'OK'},
        headers: sessionHeaders(
          accessToken: FakeSessionApi.accessToken,
          refreshToken: FakeSessionApi.refreshToken,
        ),
      );

      final result = await sut.signIn(email: _email, password: _password);

      expect(result, const SignInSuccess());
      expect(await api.run(sut.hasSession), isTrue);
      expect(await api.run(sut.isSecondFactorPending), isFalse);
    });

    test('deve ler a segunda etapa pendente da sessão aberta no login (RM08)', () async {
      api.adapter.reply(
        200,
        body: {'status': 'OK'},
        headers: sessionHeaders(
          accessToken: FakeSessionApi.accessToken,
          refreshToken: FakeSessionApi.refreshToken,
          payload: {
            secondFactorClaimKey: {'v': false, 't': 1},
          },
        ),
      );

      await sut.signIn(email: _email, password: _password);

      expect(await api.run(sut.isSecondFactorPending), isTrue);
    });

    test('não deve guardar sessão quando o login é recusado', () async {
      api.adapter.reply(200, body: {'status': 'WRONG_CREDENTIALS_ERROR'});

      final result = await sut.signIn(email: _email, password: _password);

      expect(result, const SignInWrongCredentials());
      expect(await api.run(sut.hasSession), isFalse);
    });

    test('deve devolver o SignInRateLimited no 429, depois do interceptor do SDK', () async {
      api.adapter.reply(
        429,
        body: {'statusCode': 429, 'message': 'Muitas requisições.'},
        headers: {'retry-after': '30'},
      );

      final result = await sut.signIn(email: _email, password: _password);

      expect(result, const SignInRateLimited(retryAfter: Duration(seconds: 30)));
    });
  });
}
