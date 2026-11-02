import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';

/// Faz uma chamada à API e converte qualquer erro numa [ApiException]. Os repositórios passam
/// por aqui a requisição e a leitura da resposta:
///
/// ```dart
/// Future<HealthStatus> check() => callApi(() async {
///   final response = await _dio.get<Object?>('/health');
///   return HealthStatusDto.fromJson(response.data).toModel();
/// });
/// ```
///
/// Um erro inesperado, como uma resposta fora do formato, vira [ServerException]: a tela mostra
/// a mensagem padrão, e o app não cai.
Future<T> callApi<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on Object catch (error, stackTrace) {
    final exception = toApiException(error);
    if (kDebugMode && exception is ServerException && error is! DioException) {
      // Fora do Dio, é um defeito do app ou uma resposta fora do formato: vale ver o motivo.
      debugPrint('callApi: erro inesperado, convertido em ServerException: $error\n$stackTrace');
    }
    Error.throwWithStackTrace(exception, stackTrace);
  }
}

/// Converte o erro de uma chamada à API na [ApiException] correspondente.
ApiException toApiException(Object error) => switch (error) {
  ApiException() => error,
  DioException() => _fromDioException(error),
  _ => ServerException(cause: error),
};

ApiException _fromDioException(DioException error) {
  // Um interceptor pode ter rejeitado a requisição com uma ApiException.
  if (error.error case final ApiException inner) return inner;

  final response = error.response;

  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.transformTimeout => const NetworkException(isTimeout: true),
    DioExceptionType.connectionError ||
    DioExceptionType.badCertificate ||
    DioExceptionType.cancel => const NetworkException(),
    DioExceptionType.badResponse when response != null => _fromResponse(response),
    DioExceptionType.unknown when error.error is SocketException || error.error is HttpException =>
      const NetworkException(),
    DioExceptionType.badResponse ||
    DioExceptionType.unknown => ServerException(statusCode: response?.statusCode, cause: error),
  };
}

ApiException _fromResponse(Response<dynamic> response) {
  final status = response.statusCode;
  final body = _ErrorBody.from(response.data);

  return switch (status) {
    400 => ValidationException(message: body.message, fieldErrors: body.fieldErrors),
    401 => UnauthorizedException(message: body.message, field: body.field),
    403 when body.hasClaimValidationErrors => const SecondFactorPendingException(),
    403 => ForbiddenException(message: body.message),
    404 => NotFoundException(message: body.message),
    409 => ConflictException(message: body.message, field: body.field),
    422 => BusinessRuleException(message: body.message),
    429 => RateLimitException(message: body.message, retryAfter: _retryAfter(response.headers)),
    _ => ServerException(statusCode: status),
  };
}

/// O `Retry-After` do 429, em segundos. A API não usa o formato de data do header.
Duration? _retryAfter(Headers headers) {
  final value = headers['retry-after']?.firstOrNull;
  final seconds = value == null ? null : int.tryParse(value.trim());

  return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
}

/// O que interessa do corpo de um erro. A `message` e os `details` só são lidos no formato de
/// erro da aplicação (com o `statusCode`). Os corpos do SuperTokens, em inglês, só servem para
/// reconhecer a sessão pendente da segunda etapa.
final class _ErrorBody {
  const new({
    this.message,
    this.fieldErrors = const [],
    this.field,
    this.hasClaimValidationErrors = false,
  });

  factory from(Object? data) {
    final json = _asJsonObject(data);
    if (json == null) return const _ErrorBody();

    if (json['statusCode'] is! int) {
      return _ErrorBody(hasClaimValidationErrors: json['claimValidationErrors'] is List);
    }

    final details = json['details'];

    return _ErrorBody(
      message: switch (json['message']) {
        final String message when message.trim().isNotEmpty => message,
        _ => null,
      },
      fieldErrors: [
        if (details is List)
          for (final item in details)
            if (item case {'field': final String field, 'message': final String message})
              FieldError(field: field, message: message),
      ],
      // 401 e 409: `details` é um objeto com o campo, ex.: `{ "field": "email" }`.
      field: switch (details) {
        {'field': final String field} => field,
        _ => null,
      },
    );
  }

  final String? message;
  final List<FieldError> fieldErrors;
  final String? field;
  final bool hasClaimValidationErrors;
}

Map<String, dynamic>? _asJsonObject(Object? data) {
  if (data is Map<String, dynamic>) return data;
  if (data is! String || data.isEmpty) return null;

  try {
    final decoded = jsonDecode(data);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}
