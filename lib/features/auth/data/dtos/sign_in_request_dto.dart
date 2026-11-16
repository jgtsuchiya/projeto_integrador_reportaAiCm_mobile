import 'package:reportaai_cm/features/auth/domain/models/email.dart';

/// O corpo do `POST /api/auth/signin`, no formato do SuperTokens:
/// `{ "formFields": [{ "id": "email", "value": "..." }, { "id": "password", "value": "..." }] }`.
final class SignInRequestDto {
  const new({required this.email, required this.password});

  final String email;
  final String password;

  /// O e-mail vai sem os espaços das pontas e em minúsculas, como a API o guarda (RN02). A senha
  /// vai como foi digitada.
  Map<String, Object?> toJson() => {
    'formFields': [
      {'id': 'email', 'value': normalizeEmail(email)},
      {'id': 'password', 'value': password},
    ],
  };
}
