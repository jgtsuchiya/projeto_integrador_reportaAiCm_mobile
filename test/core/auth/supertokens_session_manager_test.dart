import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/auth/session_manager.dart';
import 'package:reportaai_cm/core/auth/supertokens_session_manager.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_session_api.dart';
import '../../support/pump_app.dart';

void main() {
  late SuperTokensSessionManager sut;
  late FakeSessionApi api;
  late List<SessionEvent> events;

  setUpAll(() {
    sut = FakeSessionApi.initialize();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = FakeSessionApi();
    events = [];
    final subscription = sut.events.listen(events.add);
    addTearDown(subscription.cancel);
  });

  tearDown(() => api.endSession());

  group('SuperTokensSessionManager', () {
    test('deve devolver a mesma instância nas inicializações seguintes', () {
      expect(SuperTokensSessionManager.initialize(testConfig), same(sut));
    });

    group('hasSession', () {
      test('não deve ter sessão antes do login', () async {
        expect(await sut.hasSession(), isFalse);
      });

      test('deve ter a sessão que voltou nos headers do login, sem chamar a API', () async {
        await api.signIn();

        final result = await api.run(sut.hasSession);

        expect(result, isTrue);
        expect(api.requests, isEmpty);
      });

      test('deve renovar o access token vencido antes de responder', () async {
        await api.signIn(expired: true);
        api.reply(
          200,
          headers: sessionHeaders(accessToken: 'access-token-novo', refreshToken: 'refresh-novo'),
        );

        final result = await api.run(sut.hasSession);

        expect(result, isTrue);
        final refresh = api.requests.single;
        expect(refresh.url.path, '/api/auth/session/refresh');
        expect(refresh.headers['Authorization'], 'Bearer ${FakeSessionApi.refreshToken}');
      });

      test('deve manter a sessão sem rede para renovar o access token vencido (RM06)', () async {
        await api.signIn(expired: true);
        api.failWithoutConnection();

        final result = await api.run(sut.hasSession);
        await pumpEventQueue();

        expect(result, isTrue);
        expect(events, isEmpty);
      });

      test('deve apagar a sessão e avisar quando a API recusa a renovação (RM07)', () async {
        await api.signIn(expired: true);
        api.reply(401, headers: clearedSessionHeaders, body: {'message': 'unauthorised'});

        final result = await api.run(sut.hasSession);
        await pumpEventQueue();

        expect(result, isFalse);
        expect(events, [SessionEvent.expired]);
      });
    });

    group('isSecondFactorPending', () {
      test('deve marcar a sessão pendente pela claim mfa-verified em false (RN25)', () async {
        await api.signIn(
          payload: {
            'mfa-verified': {'v': false, 't': 1},
          },
        );

        expect(await api.run(sut.isSecondFactorPending), isTrue);
      });

      test('não deve marcar a sessão com a segunda etapa concluída', () async {
        await api.signIn(
          payload: {
            'mfa-verified': {'v': true, 't': 1},
          },
        );

        expect(await api.run(sut.isSecondFactorPending), isFalse);
      });

      test('deve ler a claim do access token renovado, quando o guardado venceu', () async {
        await api.signIn(expired: true);
        api.reply(
          200,
          headers: sessionHeaders(
            accessToken: 'access-token-novo',
            refreshToken: 'refresh-novo',
            payload: {
              'mfa-verified': {'v': false, 't': 1},
            },
          ),
        );

        expect(await api.run(sut.isSecondFactorPending), isTrue);
      });

      test('deve lançar a NetworkException sem rede para renovar a sessão (RM06)', () async {
        await api.signIn(expired: true);
        api.failWithoutConnection();

        await expectLater(api.run(sut.isSecondFactorPending), throwsA(isA<NetworkException>()));
        expect(await api.run(sut.hasSession), isTrue);
      });

      test('deve lançar a UnauthorizedException quando a API recusa a renovação', () async {
        await api.signIn(expired: true);
        api.reply(401, headers: clearedSessionHeaders, body: {'message': 'unauthorised'});

        await expectLater(
          api.run(sut.isSecondFactorPending),
          throwsA(isA<UnauthorizedException>()),
        );
        await pumpEventQueue();

        expect(events, [SessionEvent.expired]);
      });

      test('deve lançar a UnauthorizedException sem sessão', () async {
        await expectLater(
          api.run(sut.isSecondFactorPending),
          throwsA(isA<UnauthorizedException>()),
        );
      });
    });

    group('signOut', () {
      test('deve encerrar a sessão na API, apagar os tokens e avisar a saída', () async {
        await api.signIn();
        api.reply(200, headers: clearedSessionHeaders);

        await api.run(sut.signOut);
        await pumpEventQueue();

        final request = api.requests.single;
        expect(request.url.path, '/api/auth/signout');
        expect(request.headers['Authorization'], 'Bearer ${FakeSessionApi.accessToken}');
        expect(await sut.hasSession(), isFalse);
        expect(events, [SessionEvent.signedOut]);
      });

      test('deve manter a sessão e lançar a NetworkException sem conexão (RM10)', () async {
        await api.signIn();
        api.failWithoutConnection();

        await expectLater(api.run(sut.signOut), throwsA(isA<NetworkException>()));
        await pumpEventQueue();

        expect(await api.run(sut.hasSession), isTrue);
        expect(events, isEmpty);
      });

      test('deve manter a sessão sem rede com o access token vencido (RM10)', () async {
        // O SDK não chega a chamar o signout: a renovação falha, e ele avisa a saída sem apagar
        // os tokens.
        await api.signIn(expired: true);
        api.failWithoutConnection();

        await expectLater(api.run(sut.signOut), throwsA(isA<NetworkException>()));
        await pumpEventQueue();

        expect(await api.run(sut.hasSession), isTrue);
        expect(events, isEmpty);
      });

      test('deve manter a sessão quando a API responde com erro', () async {
        await api.signIn();
        api.reply(500, body: {'statusCode': 500, 'message': 'Erro interno'});

        await expectLater(api.run(sut.signOut), throwsA(isA<NetworkException>()));

        expect(await api.run(sut.hasSession), isTrue);
      });

      test('deve sair sem chamar a API quando não há sessão', () async {
        await api.run(sut.signOut);
        await pumpEventQueue();

        expect(api.requests, isEmpty);
        expect(events, [SessionEvent.signedOut]);
      });
    });
  });

  group('isSecondFactorPendingIn', () {
    test('deve marcar como pendente só a claim mfa-verified com v em false', () {
      final cases = <Map<String, dynamic>, bool>{
        {
          'mfa-verified': {'v': false, 't': 1},
        }: true,
        {
          'mfa-verified': {'v': true, 't': 1},
        }: false,
        {}: false,
        {'mfa-verified': null}: false,
        {'mfa-verified': 'false'}: false,
      };

      for (final MapEntry(key: payload, value: pending) in cases.entries) {
        expect(isSecondFactorPendingIn(payload), pending, reason: '$payload');
      }
    });
  });
}
