import 'package:reportaai_cm/features/auth/domain/models/email.dart';
import 'package:reportaai_cm/features/auth/domain/models/sign_in_result.dart';

/// A conferência do login antes de enviar (RM05): o e-mail preenchido e no formato, e a senha
/// preenchida. A política de senha (RN08) não é conferida no login, só no cadastro.
///
/// Devolve o erro de cada campo recusado, com as mesmas mensagens do `FIELD_ERROR` da API
/// ([SignInFieldError]), ou um mapa vazio quando o login pode ser enviado. A senha é conferida
/// como foi digitada, sem tirar os espaços.
Map<SignInField, String> validateSignIn({required String email, required String password}) => {
  if (email.trim().isEmpty)
    SignInField.email: SignInFieldError.emailRequiredMessage
  else if (!isValidEmail(email))
    SignInField.email: SignInFieldError.emailInvalidMessage,
  if (password.isEmpty) SignInField.password: SignInFieldError.passwordRequiredMessage,
};
