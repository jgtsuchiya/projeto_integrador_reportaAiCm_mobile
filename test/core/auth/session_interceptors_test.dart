import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/auth/session_interceptors.dart';
import 'package:reportaai_cm/core/auth/session_manager.dart';
import 'package:reportaai_cm/core/auth/supertokens_session_manager.dart';
import 'package:reportaai_cm/core/network/api_error_mapper.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/core/network/api_log_interceptor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_http_adapter.dart';
import '../../support/fake_session_api.dart';

void main() {
  late SuperTokensSessionManager sessionManager;

  setUpAll(() {
    sessionManager = FakeSessionApi.initialize();
  });

  group('sessionInterceptors', () {
    late FakeSessionApi api;
    late List<SessionEvent> events;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      api = FakeSessionApi();
      events = [];
      final subscription = sessionManager.events.listen(events.add);
      addTearDown(subscription.cancel);
    });

    tearDown(() => api.endSession());

    /// O `GET /api/users/me`, que responde 200 só com o access token [validToken].
    void replyMeOnlyWith(String validToken) {
      api.adapter.replyWith(
        (options) => options.headers['Authorization'] == 'Bearer $validToken'
            ? const FakeResponse(200, body: {'id': 'user-1'})
            : const FakeResponse(401, body: {'message': 'try refresh token'}),
      );
    }

    test('deve enviar o access token e o modo header nas chamadas seguintes ao login', () async {
      await api.signIn();
      api.adapter.reply(200, body: {'id': 'user-1'});

      final response = await api.dio.get<Object?>('/users/me');

      expect(response.statusCode, 200);
      final headers = api.adapter.requests.last.headers;
      expect(headers['Authorization'], 'Bearer ${FakeSessionApi.accessToken}');
      expect(headers['st-auth-mode'], 'header');
    });

    test('deve renovar a sessão num 401 e repetir a chamada com o token novo', () async {
      await api.signIn();
      replyMeOnlyWith('access-token-novo');
      api.reply(
        200,
        headers: sessionHeaders(accessToken: 'access-token-novo', refreshToken: 'refresh-novo'),
      );

      final response = await api.run(() => api.dio.get<Object?>('/users/me'));
      await pumpEventQueue();

      expect(response.statusCode, 200);
      expect(response.data, {'id': 'user-1'});
      expect(api.requests.single.url.path, '/api/auth/session/refresh');
      expect(api.adapter.requests.map((request) => request.uri.path), [
        '/api/auth/signin',
        '/api/users/me',
        '/api/users/me',
      ]);
      expect(events, isEmpty);
    });

    test('deve devolver o 401 como erro e avisar quando a API recusa a renovação', () async {
      await api.signIn();
      replyMeOnlyWith('access-token-novo');
      api.reply(401, headers: clearedSessionHeaders, body: {'message': 'unauthorised'});

      final call = api.run(() => callApi(() => api.dio.get<Object?>('/users/me')));

      await expectLater(call, throwsA(isA<UnauthorizedException>()));
      await pumpEventQueue();
      expect(events, [SessionEvent.expired]);
      expect(await sessionManager.hasSession(), isFalse);
    });

    test('deve devolver o 401 como erro sem sessão', () async {
      api.adapter.reply(401, body: {'message': 'unauthorised'});

      final call = api.run(() => callApi(() => api.dio.get<Object?>('/users/me')));

      await expectLater(call, throwsA(isA<UnauthorizedException>()));
      expect(api.requests, isEmpty);
    });

    test('deve manter o erro das outras respostas, como o 429 do login', () async {
      api.adapter.reply(
        429,
        body: {'statusCode': 429, 'error': 'Too Many Requests', 'message': 'Muitas tentativas.'},
        headers: {'retry-after': '30'},
      );

      final call = callApi(() => api.dio.post<Object?>('/auth/signin'));

      await expectLater(
        call,
        throwsA(
          isA<RateLimitException>().having(
            (error) => error.retryAfter,
            'retryAfter',
            const Duration(seconds: 30),
          ),
        ),
      );
    });

    test('não deve mostrar os tokens no log, no login, na renovação e na chamada', () async {
      final lines = <String>[];
      api.dio.interceptors.add(ApiLogInterceptor(log: lines.add));
      await api.signIn();
      replyMeOnlyWith('access-token-novo');
      api.reply(
        200,
        headers: sessionHeaders(accessToken: 'access-token-novo', refreshToken: 'refresh-novo'),
      );

      await api.run(() => api.dio.get<Object?>('/users/me'));

      final log = lines.join('\n');
      expect(log, contains('/api/users/me'));
      for (final secret in [
        FakeSessionApi.accessToken,
        FakeSessionApi.refreshToken,
        'access-token-novo',
        'refresh-novo',
      ]) {
        expect(log, isNot(contains(secret)), reason: secret);
      }
    });
  });

  group('UnauthorizedResponseInterceptor', () {
    test('deve devolver como erro o 401 aceito como sucesso', () async {
      final adapter = FakeHttpAdapter()..reply(401, body: {'message': 'unauthorised'});
      final dio = fakeDio(adapter)..interceptors.add(const UnauthorizedResponseInterceptor());

      final call = dio.get<Object?>(
        '/users/me',
        options: Options(validateStatus: (status) => status == 200 || status == 401),
      );

      await expectLater(
        call,
        throwsA(
          isA<DioException>()
              .having((error) => error.type, 'type', DioExceptionType.badResponse)
              .having((error) => error.response?.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('deve deixar passar as outras respostas', () async {
      final adapter = FakeHttpAdapter()..reply(200, body: {'id': 'user-1'});
      final dio = fakeDio(adapter)..interceptors.add(const UnauthorizedResponseInterceptor());

      final response = await dio.get<Object?>('/users/me');

      expect(response.data, {'id': 'user-1'});
    });
  });
}
