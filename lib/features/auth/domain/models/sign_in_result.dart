import 'package:meta/meta.dart';

/// Os campos do formulário de login, para a mensagem de erro de cada um ([SignInFieldError]).
enum SignInField { email, password }

/// O resultado do login (`POST /api/auth/signin`) quando a API responde, com uma mensagem própria
/// na tela para cada caso (RM02 a RM04). Sem conexão, o 5xx e a resposta inesperada não são
/// resultados: o `AuthRepository.signIn` os lança como as exceções do `core/network`.
@immutable
sealed class SignInResult {
  const new();
}

/// A sessão foi aberta e já está guardada no aparelho. Faltam a segunda etapa (RM08) e o papel
/// (RM01), conferidos depois.
final class SignInSuccess extends SignInResult {
  const new();

  @override
  bool operator ==(Object other) => other is SignInSuccess;

  @override
  int get hashCode => (SignInSuccess).hashCode;

  @override
  String toString() => 'SignInSuccess()';
}

/// E-mail ou senha incorretos. É também a resposta para a conta inexistente, inativa ou excluída:
/// a API não diferencia os casos (RN09), e o app mostra a mesma mensagem (RM02).
final class SignInWrongCredentials extends SignInResult {
  const new();

  @override
  bool operator ==(Object other) => other is SignInWrongCredentials;

  @override
  int get hashCode => (SignInWrongCredentials).hashCode;

  @override
  String toString() => 'SignInWrongCredentials()';
}

/// A API recusou um campo antes de conferir a senha, como o e-mail fora do formato. O [errors]
/// traz a mensagem de cada campo recusado, em português, para mostrar embaixo dele.
final class SignInFieldError extends SignInResult {
  const new(this.errors);

  static const emailRequiredMessage = 'Informe o e-mail.';
  static const emailInvalidMessage = 'E-mail inválido.';
  static const passwordRequiredMessage = 'Informe a senha.';

  final Map<SignInField, String> errors;

  /// A mensagem do [field], ou `null` quando a API aceitou o campo.
  String? messageFor(SignInField field) => errors[field];

  @override
  bool operator ==(Object other) =>
      other is SignInFieldError &&
      other.errors.length == errors.length &&
      errors.entries.every((entry) => other.errors[entry.key] == entry.value);

  @override
  int get hashCode => Object.hashAllUnordered([
    for (final MapEntry(:key, :value) in errors.entries) Object.hash(key, value),
  ]);

  @override
  String toString() => 'SignInFieldError($errors)';
}

/// O e-mail está bloqueado por tentativas (RN17): a API recusa o login, mesmo com a senha certa,
/// até uma das falhas sair da janela. A [message] é a da API, sem contagem regressiva: a API não
/// informa quanto falta (RM03).
final class SignInLocked extends SignInResult {
  const new(this.message);

  final String message;

  @override
  bool operator ==(Object other) => other is SignInLocked && other.message == message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'SignInLocked($message)';
}

/// Muitas tentativas de login do mesmo IP (RN18): a API recusa o login até o fim do
/// [retryAfter], e o "Entrar" fica desativado com a contagem regressiva (RM04).
final class SignInRateLimited extends SignInResult {
  const new({required this.retryAfter});

  /// A espera quando a API não manda o `Retry-After`: a janela inteira do limite, de 1 minuto.
  static const defaultRetryAfter = Duration(minutes: 1);

  final Duration retryAfter;

  @override
  bool operator ==(Object other) => other is SignInRateLimited && other.retryAfter == retryAfter;

  @override
  int get hashCode => retryAfter.hashCode;

  @override
  String toString() => 'SignInRateLimited(retryAfter: $retryAfter)';
}
