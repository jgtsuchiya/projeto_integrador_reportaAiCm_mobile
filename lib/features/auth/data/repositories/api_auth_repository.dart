import 'package:dio/dio.dart';
import 'package:reportaai_cm/core/auth/session_manager.dart';
import 'package:reportaai_cm/core/network/api_error_mapper.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/data/dtos/sign_in_request_dto.dart';
import 'package:reportaai_cm/features/auth/data/dtos/sign_in_response_dto.dart';
import 'package:reportaai_cm/features/auth/domain/models/sign_in_result.dart';
import 'package:reportaai_cm/features/auth/domain/repositories/auth_repository.dart';

/// [AuthRepository] que faz o login pelo `POST /api/auth/signin`, no `Dio` compartilhado, e deixa
/// o resto da sessão com o [SessionManager]. O SDK do SuperTokens não tem função de login: o
/// interceptor dele, no `Dio`, guarda a sessão que volta nos headers da resposta.
final class ApiAuthRepository implements AuthRepository {
  const new(this._dio, this._session);

  final Dio _dio;
  final SessionManager _session;

  @override
  Future<SignInResult> signIn({required String email, required String password}) async {
    try {
      return await callApi(() async {
        final body = SignInRequestDto(email: email, password: password).toJson();
        final response = await _dio.post<Object?>('/auth/signin', data: body);
        return SignInResponseDto.fromJson(response.data).toModel();
      });
    } on ApiException catch (error, stackTrace) {
      switch (error) {
        // O limite por IP (RN18) é um resultado do login, mas vem como erro: um 429 no formato de
        // erro da aplicação, sem o `status`.
        case RateLimitException(:final retryAfter):
          return SignInRateLimited(retryAfter: retryAfter ?? SignInRateLimited.defaultRetryAfter);
        case NetworkException() || ServerException():
          rethrow;
        // Fora o 429, o signin só responde 200. Outro status, como o 404 de uma API_URL que aponta
        // para outro servidor, é uma resposta inesperada, com a mensagem padrão na tela.
        case _:
          Error.throwWithStackTrace(ServerException(cause: error), stackTrace);
      }
    }
  }

  @override
  Future<void> signOut() => callApi(_session.signOut);

  @override
  Future<bool> hasSession() => callApi(_session.hasSession);

  @override
  Future<bool> isSecondFactorPending() => callApi(_session.isSecondFactorPending);
}
