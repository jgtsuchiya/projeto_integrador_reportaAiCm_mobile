import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:reportaai_cm/core/config/app_config.dart';
import 'package:reportaai_cm/core/network/dio_provider.dart';

import 'pump_app.dart';

/// Uma resposta do [FakeHttpAdapter]: o [status], o [body] em JSON e os [headers].
final class FakeResponse {
  const new(this.status, {this.body, this.headers = const {}});

  final int status;
  final Object? body;
  final Map<String, String> headers;
}

/// Adapter do Dio que responde sem rede. O teste define a resposta (ou a falha) das próximas
/// requisições e confere as que foram feitas em [requests].
final class FakeHttpAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  ResponseBody Function(RequestOptions options)? _reply;

  /// Responde com o [status], o [body] em JSON e os [headers].
  void reply(int status, {Object? body, Map<String, String> headers = const {}}) {
    replyWith((_) => FakeResponse(status, body: body, headers: headers));
  }

  /// Responde conforme a requisição, para a resposta que muda entre as chamadas (ex.: o 401 com o
  /// access token vencido e o 200 com o renovado).
  void replyWith(FakeResponse Function(RequestOptions options) reply) {
    _reply = (options) {
      final FakeResponse(:status, :body, :headers) = reply(options);

      return ResponseBody.fromString(
        body == null ? '' : jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          for (final MapEntry(:key, :value) in headers.entries) key: [value],
        },
      );
    };
  }

  /// Responde com um corpo que não é JSON, como a página de erro de um proxy.
  void replyText(int status, String text) {
    _reply = (_) => ResponseBody.fromString(
      text,
      status,
      headers: {
        Headers.contentTypeHeader: ['text/html'],
      },
    );
  }

  /// Falha antes de chegar à API, como o Dio sem conexão ou no timeout.
  void failWith(DioExceptionType type) {
    _reply = (options) =>
        throw DioException(requestOptions: options, type: type, message: 'falha simulada');
  }

  /// Lança o [error] de dentro do adapter, como o `HttpClient` do `dart:io`.
  void throwError(Exception error) {
    _reply = (_) => throw error;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    final reply = _reply;
    if (reply == null) {
      throw StateError('O teste não definiu a resposta de ${options.method} ${options.uri}.');
    }

    return reply(options);
  }

  @override
  void close({bool force = false}) {}
}

/// O `Dio` do app (o mesmo `createDio`), com o [adapter] no lugar da rede. Com [withSession], tem
/// os interceptors do SuperTokens, que pedem o SDK inicializado (ver o `FakeSessionApi`).
Dio fakeDio(FakeHttpAdapter adapter, {AppConfig? config, bool withSession = false}) =>
    createDio(config ?? testConfig, withSession: withSession)..httpClientAdapter = adapter;
