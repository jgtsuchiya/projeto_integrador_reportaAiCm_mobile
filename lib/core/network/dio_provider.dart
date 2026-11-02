import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/core/config/app_config.dart';
import 'package:reportaai_cm/core/config/app_config_provider.dart';
import 'package:reportaai_cm/core/network/api_log_interceptor.dart';

const apiConnectTimeout = Duration(seconds: 10);
const apiReceiveTimeout = Duration(seconds: 15);

/// O cliente HTTP único do app. Todos os repositórios falam com a API por ele.
///
/// No épico de login, o SDK do SuperTokens registra o interceptor dele aqui, antes do de log.
final dioProvider = Provider<Dio>((ref) {
  final dio = createDio(ref.watch(appConfigProvider), logRequests: kDebugMode);
  ref.onDispose(dio.close);
  return dio;
});

/// Monta o [Dio] com a base `${API_URL}/api`, JSON e os timeouts. Os caminhos das chamadas
/// começam com `/`, sem o prefixo: `dio.get('/health')` chama `GET /api/health`.
Dio createDio(AppConfig config, {bool logRequests = false}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: apiConnectTimeout,
      receiveTimeout: apiReceiveTimeout,
      contentType: Headers.jsonContentType,
      headers: {Headers.acceptHeader: Headers.jsonContentType},
    ),
  );

  if (logRequests) {
    dio.interceptors.add(ApiLogInterceptor());
  }

  return dio;
}
