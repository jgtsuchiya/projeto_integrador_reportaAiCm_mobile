import 'package:dio/dio.dart';
import 'package:supertokens_flutter/dio.dart';

/// Os interceptors da sessão, para o `Dio` compartilhado, antes do de log. O SDK precisa estar
/// inicializado (`SuperTokensSessionManager.initialize`): sem ele, toda requisição é recusada.
///
/// - O do SDK põe o access token no `Authorization`, guarda os tokens que voltam nos headers e,
///   num 401, renova a sessão e repete a chamada.
/// - O [UnauthorizedResponseInterceptor] devolve como erro o 401 que o SDK deixa passar.
List<Interceptor> sessionInterceptors(Dio dio) => [
  SuperTokensInterceptorWrapper(client: dio),
  const UnauthorizedResponseInterceptor(),
];

/// Para tratar o 401, o interceptor do SDK aceita esse status como sucesso. Quando a sessão não
/// renova, ele entrega o 401 como uma resposta comum, e o repositório tentaria ler o corpo do
/// erro como dado. Este interceptor o devolve como o erro que o Dio daria, e o `callApi` o
/// converte na `UnauthorizedException`.
final class UnauthorizedResponseInterceptor extends Interceptor {
  const new();

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (response.statusCode != 401) return handler.next(response);

    handler.reject(
      DioException.badResponse(
        statusCode: 401,
        requestOptions: response.requestOptions,
        response: response,
      ),
      // O log, que vem depois, registra o 401 como erro.
      true,
    );
  }
}
