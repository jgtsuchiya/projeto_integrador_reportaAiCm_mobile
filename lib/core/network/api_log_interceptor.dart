import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Log das requisições à API no console. O `dioProvider` só o adiciona em debug.
///
/// O log nunca mostra a sessão nem dados pessoais:
///
/// - os headers de [sensitiveHeaders] saem como `***`, na ida e na volta;
/// - o corpo das rotas de `/api/auth` (login, renovação e saída) não aparece;
/// - nos outros corpos e na query, os campos de [sensitiveFields] saem como `***`.
final class ApiLogInterceptor extends Interceptor {
  new({void Function(String message)? log}) : _log = log ?? debugPrint;

  static const redacted = '***';

  /// Os quatro primeiros levam a sessão do SuperTokens no modo header, o do app.
  static const sensitiveHeaders = {
    'authorization',
    'st-access-token',
    'st-refresh-token',
    'front-token',
    'anti-csrf',
    'cookie',
    'set-cookie',
  };

  /// Comparados sem diferenciar maiúsculas de minúsculas.
  static const sensitiveFields = {
    'password',
    'currentpassword',
    'newpassword',
    'token',
    'code',
    'cpf',
  };

  static const _maxBodyLength = 2000;
  static const _stopwatchKey = 'apiLogStopwatch';
  static final _authRoute = RegExp(r'/api/auth(/|$)');

  final void Function(String message) _log;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_stopwatchKey] = Stopwatch()..start();
    _log(
      [
        '→ ${options.method} ${_uri(options.uri)}',
        '  headers: ${_headers(options.headers)}',
        if (options.data != null) '  body: ${_body(options.uri, options.data)}',
      ].join('\n'),
    );
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final options = response.requestOptions;
    _log(
      [
        '← ${response.statusCode} ${options.method} ${_uri(options.uri)}${_elapsed(options)}',
        '  headers: ${_headers(response.headers.map)}',
        if (response.data != null) '  body: ${_body(options.uri, response.data)}',
      ].join('\n'),
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    final response = err.response;
    final status = response?.statusCode ?? err.type.name;
    _log(
      [
        '✖ $status ${options.method} ${_uri(options.uri)}${_elapsed(options)}',
        if (response != null) '  headers: ${_headers(response.headers.map)}',
        if (response?.data != null) '  body: ${_body(options.uri, response?.data)}',
      ].join('\n'),
    );
    handler.next(err);
  }

  String _uri(Uri uri) {
    if (!uri.hasQuery) return uri.toString();

    final safe = uri.replace(
      queryParameters: {
        for (final MapEntry(:key, :value) in uri.queryParametersAll.entries)
          key: _isSensitiveField(key) ? redacted : value,
      },
    );

    // Decodificado só para leitura: `token=***` em vez de `token=%2A%2A%2A`.
    return Uri.decodeFull(safe.toString());
  }

  String _headers(Map<String, Object?> headers) {
    final safe = {
      for (final MapEntry(:key, :value) in headers.entries)
        key: sensitiveHeaders.contains(key.toLowerCase()) ? redacted : _headerValue(value),
    };

    return safe.toString();
  }

  String _body(Uri uri, Object? data) {
    if (_authRoute.hasMatch(uri.path)) return '(omitido nas rotas de /api/auth)';

    final json = _asJson(data);
    if (json == null) {
      return switch (data) {
        FormData(:final fields, :final files) =>
          '(multipart: ${fields.length} campos e ${files.length} arquivos)',
        String() => '(texto com ${data.length} caracteres)',
        _ => '(${data.runtimeType})',
      };
    }

    final text = jsonEncode(_mask(json), toEncodable: (value) => value.toString());

    return text.length <= _maxBodyLength
        ? text
        : '${text.substring(0, _maxBodyLength)}… (${text.length} caracteres)';
  }

  String _elapsed(RequestOptions options) => switch (options.extra[_stopwatchKey]) {
    final Stopwatch stopwatch => ' (${stopwatch.elapsedMilliseconds} ms)',
    _ => '',
  };
}

bool _isSensitiveField(String key) => ApiLogInterceptor.sensitiveFields.contains(key.toLowerCase());

Object? _headerValue(Object? value) => value is List ? value.join(', ') : value;

/// O corpo já decodificado (mapa ou lista) ou `null` quando não é JSON.
Object? _asJson(Object? data) {
  if (data is Map || data is List) return data;
  if (data is! String) return null;

  try {
    final decoded = jsonDecode(data);
    return decoded is Map || decoded is List ? decoded : null;
  } on FormatException {
    return null;
  }
}

Object? _mask(Object? value) => switch (value) {
  Map<dynamic, dynamic>() => {
    for (final MapEntry(:key, value: item) in value.entries)
      key.toString(): _isSensitiveField(key.toString()) ? ApiLogInterceptor.redacted : _mask(item),
  },
  List<dynamic>() => [for (final item in value) _mask(item)],
  _ => value,
};
