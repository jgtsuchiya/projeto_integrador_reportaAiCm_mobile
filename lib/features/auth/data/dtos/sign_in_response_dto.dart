import 'package:reportaai_cm/features/auth/domain/models/sign_in_result.dart';

/// A resposta 200 do `POST /api/auth/signin`, no formato do SuperTokens: o resultado vem no
/// `status`, como `{ "status": "WRONG_CREDENTIALS_ERROR" }`. O 429 não chega aqui: ele vem no
/// formato de erro da aplicação, e o `Dio` o lança como erro.
final class SignInResponseDto {
  const new({required this.status, this.message, this.formFields = const []});

  /// Lança uma [FormatException] quando o JSON não tem o `status`. O `callApi` a converte em
  /// `ServerException`.
  factory fromJson(Object? json) {
    if (json case {'status': final String status}) {
      return SignInResponseDto(
        status: status,
        message: switch (json) {
          {'message': final String message} => message,
          _ => null,
        },
        formFields: switch (json) {
          {'formFields': final List<Object?> fields} => [
            for (final field in fields)
              if (field case {'id': final String id, 'error': final String error})
                (id: id, error: error),
          ],
          _ => const [],
        },
      );
    }

    throw const FormatException(
      'A resposta do POST /api/auth/signin está fora do formato esperado.',
    );
  }

  /// O que o SuperTokens responde no campo vazio, em qualquer formulário.
  static const _requiredFieldError = 'Field is not optional';

  final String status;

  /// Só no `GENERAL_ERROR`: a mensagem da API, em português.
  final String? message;

  /// Só no `FIELD_ERROR`: o erro de cada campo, em inglês, escrito pelo SuperTokens.
  final List<({String id, String error})> formFields;

  /// Lança uma [FormatException] quando o `status` é um que o app não conhece, ou quando falta
  /// o que ele precisa (a `message` do `GENERAL_ERROR` e os campos do `FIELD_ERROR`).
  SignInResult toModel() => switch (status) {
    'OK' => const SignInSuccess(),
    'WRONG_CREDENTIALS_ERROR' => const SignInWrongCredentials(),
    'FIELD_ERROR' => _toFieldError(),
    'GENERAL_ERROR' => switch (message?.trim()) {
      final String message when message.isNotEmpty => SignInLocked(message),
      _ => throw const FormatException('O GENERAL_ERROR do login veio sem a message.'),
    },
    _ => throw FormatException('O login respondeu um status que o app não conhece: $status.'),
  };

  /// As mensagens do SuperTokens vêm em inglês: o app mostra as dele, por campo. No login, a API
  /// só confere se o e-mail está preenchido e no formato e se a senha está preenchida.
  SignInFieldError _toFieldError() {
    final errors = {
      for (final (:id, :error) in formFields)
        if (id == 'email')
          SignInField.email: error == _requiredFieldError
              ? SignInFieldError.emailRequiredMessage
              : SignInFieldError.emailInvalidMessage
        else if (id == 'password')
          SignInField.password: SignInFieldError.passwordRequiredMessage,
    };

    if (errors.isEmpty) {
      throw const FormatException('O FIELD_ERROR do login não trouxe um campo do formulário.');
    }

    return SignInFieldError(Map.unmodifiable(errors));
  }
}
