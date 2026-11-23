import 'package:dio/dio.dart';
import 'package:reportaai_cm/core/network/api_error_mapper.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/data/dtos/register_client_request_dto.dart';
import 'package:reportaai_cm/features/auth/domain/models/client_registration.dart';
import 'package:reportaai_cm/features/auth/domain/models/registration_result.dart';
import 'package:reportaai_cm/features/auth/domain/repositories/registration_repository.dart';

/// [RegistrationRepository] que cria a conta pelo `POST /api/clients`, no `Dio` compartilhado. A
/// rota é pública: sem sessão no aparelho, o SDK do SuperTokens não põe nenhum header.
///
/// O corpo da resposta 201 (o perfil criado) não é lido: o app entra em seguida e lê o perfil do
/// `GET /api/users/me`, como em qualquer login.
final class ApiRegistrationRepository implements RegistrationRepository {
  const new(this._dio);

  final Dio _dio;

  @override
  Future<RegistrationResult> register(ClientRegistration registration) async {
    try {
      await callApi(
        () => _dio.post<Object?>('/clients', data: RegisterClientRequestDto(registration).toJson()),
      );
      return const RegistrationSuccess();
    } on ApiException catch (error) {
      switch (error) {
        // 400: a mensagem de cada campo do `details`, a primeira de cada um.
        case ValidationException(:final fieldErrors):
          final errors = <RegistrationField, String>{};
          for (final FieldError(:field, :message) in fieldErrors) {
            if (RegistrationField.fromApiName(field) case final known?) {
              errors.putIfAbsent(known, () => message);
            }
          }
          if (errors.isNotEmpty) return RegistrationFieldErrors(Map.unmodifiable(errors));

        // 409: o e-mail ou o CPF que já tem conta, com a mensagem da API.
        case ConflictException(:final field, :final message):
          if (RegistrationField.fromApiName(field) case final known?) {
            return RegistrationFieldErrors({known: message}, alreadyInUse: known);
          }

        // O limite por IP (RN18), como no login.
        case RateLimitException(:final retryAfter):
          return RegistrationRateLimited(
            retryAfter: retryAfter ?? RegistrationRateLimited.defaultRetryAfter,
          );

        case _:
          break;
      }

      // Sem um campo que o app conheça, a tela mostra a mensagem geral da exceção.
      rethrow;
    }
  }
}
