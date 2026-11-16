import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reportaai_cm/core/auth/supertokens_session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_http_adapter.dart';
import 'pump_app.dart';

/// A API do SuperTokens para os testes do `core/auth/`, que usam o SDK de verdade, sem rede. O
/// SDK fala com a API por dois caminhos:
///
/// - pelo `Dio` do app ([dio], com o [adapter] no lugar da rede): o login e as outras rotas;
/// - pelo pacote `http`, fora do Dio: a renovação da sessão e o signout. O teste define a
///   resposta delas com o [reply] ou o [failWithoutConnection] e roda dentro do [run].
///
/// O SDK guarda a sessão em variáveis globais, além do SharedPreferences: ele é inicializado uma
/// vez por arquivo ([initialize], no `setUpAll`), e cada teste encerra a sessão no fim
/// ([endSession], no `tearDown`).
final class FakeSessionApi {
  static const accessToken = 'access-token-do-login';
  static const refreshToken = 'refresh-token-do-login';

  /// Inicializa o SDK com a configuração de teste e o SharedPreferences em memória.
  static SuperTokensSessionManager initialize() {
    SharedPreferences.setMockInitialValues({});
    return SuperTokensSessionManager.initialize(testConfig);
  }

  final adapter = FakeHttpAdapter();
  late final Dio dio = fakeDio(adapter, withSession: true);

  /// As chamadas que o SDK fez pelo pacote `http`.
  final requests = <http.Request>[];

  http.Response Function(http.Request request)? _reply;

  /// Responde às chamadas do pacote `http` com o [status], os [headers] e o [body] em JSON.
  void reply(int status, {Map<String, String> headers = const {}, Object? body}) {
    _reply = (_) => http.Response(jsonEncode(body ?? {'status': 'OK'}), status, headers: headers);
  }

  /// As chamadas do pacote `http` falham sem chegar à API, como sem conexão.
  void failWithoutConnection() {
    _reply = (request) => throw http.ClientException('falha simulada', request.url);
  }

  /// Roda o [body] com as respostas definidas no [reply] no lugar da rede do pacote `http`.
  Future<T> run<T>(Future<T> Function() body) =>
      http.runWithClient(body, () => MockClient(_handle));

  /// Faz o login pelo [dio], como o app, com a API devolvendo a sessão nos headers. Com
  /// [expired], o access token já chega vencido, e a chamada seguinte renova a sessão.
  Future<void> signIn({Map<String, Object?> payload = const {}, bool expired = false}) async {
    adapter.reply(
      200,
      body: {'status': 'OK'},
      headers: sessionHeaders(
        accessToken: accessToken,
        refreshToken: refreshToken,
        payload: payload,
        expired: expired,
      ),
    );
    await dio.post<Object?>('/auth/signin');
  }

  /// Apaga a sessão do aparelho, como a resposta do signout da API.
  Future<void> endSession() async {
    adapter.reply(200, body: {'status': 'OK'}, headers: clearedSessionHeaders);
    await dio.post<Object?>('/auth/signout');
  }

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);

    final reply = _reply;
    if (reply == null) {
      throw StateError('O teste não definiu a resposta de ${request.method} ${request.url}.');
    }

    return reply(request);
  }
}

/// Os headers com que a API abre e renova a sessão no modo header: os dois tokens e o front
/// token, com o [payload] do access token, que o SDK lê sem chamar a API.
Map<String, String> sessionHeaders({
  required String accessToken,
  required String refreshToken,
  Map<String, Object?> payload = const {},
  bool expired = false,
}) {
  final expiresAt = DateTime.now().add(Duration(minutes: expired ? -1 : 15));
  final frontToken = {'uid': 'user-1', 'ate': expiresAt.millisecondsSinceEpoch, 'up': payload};

  return {
    'front-token': base64Encode(utf8.encode(jsonEncode(frontToken))),
    'st-access-token': accessToken,
    'st-refresh-token': refreshToken,
  };
}

/// Os headers com que a API apaga a sessão do aparelho, no signout e na renovação recusada.
const clearedSessionHeaders = {
  'front-token': 'remove',
  'st-access-token': '',
  'st-refresh-token': '',
};
