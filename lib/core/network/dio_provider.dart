import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/core/auth/session_interceptors.dart';
import 'package:reportaai_cm/core/config/app_config.dart';
import 'package:reportaai_cm/core/config/app_config_provider.dart';
import 'package:reportaai_cm/core/network/api_log_interceptor.dart';
import 'package:reportaai_cm/core/network/user_agent.dart';

const apiConnectTimeout = Duration(seconds: 10);
const apiReceiveTimeout = Duration(seconds: 15);

/// O cliente HTTP único do app, com a sessão do usuário e o `User-Agent` do app. Todos os
/// repositórios falam com a API por ele.
final dioProvider = Provider<Dio>((ref) {
  final dio = createDio(
    ref.watch(appConfigProvider),
    withSession: true,
    logRequests: kDebugMode,
    userAgent: ref.watch(userAgentProvider),
  );
  ref.onDispose(dio.close);
  return dio;
});

/// Monta o [Dio] com a base `${API_URL}/api`, JSON e os timeouts. Os caminhos das chamadas
/// começam com `/`, sem o prefixo: `dio.get('/health')` chama `GET /api/health`.
///
/// Com [withSession], o SDK do SuperTokens envia e renova a sessão em cada chamada. Ele entra
/// antes do log, que mostra a requisição com o `Authorization` (mascarado) e a resposta depois
/// da renovação.
///
/// O [userAgent] vai em todas as chamadas. A API grava o do login, e a lista de sessões abertas o
/// mostra. Sem ele, vale o padrão do `dart:io` (`Dart/3.13 (dart:io)`).
Dio createDio(
  AppConfig config, {
  bool withSession = false,
  bool logRequests = false,
  String? userAgent,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: apiConnectTimeout,
      receiveTimeout: apiReceiveTimeout,
      contentType: Headers.jsonContentType,
      headers: {Headers.acceptHeader: Headers.jsonContentType, 'user-agent': ?userAgent},
    ),
  );

  if (withSession) {
    dio.interceptors.addAll(sessionInterceptors(dio));
  }

  if (logRequests) {
    dio.interceptors.add(ApiLogInterceptor());
  }

  return dio;
}
