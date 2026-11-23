import 'package:meta/meta.dart';
import 'package:reportaai_cm/features/auth/domain/models/client_registration.dart';

/// O resultado do cadastro (`POST /api/clients`) quando a API responde, com uma mensagem própria
/// na tela para cada caso (RM11 e RM12). Sem conexão, o 5xx e a resposta inesperada não são
/// resultados: o `RegistrationRepository.register` os lança como as exceções do `core/network`.
@immutable
sealed class RegistrationResult {
  const new();
}

/// A conta foi criada (201). Falta entrar: o cadastro não abre a sessão, e o app faz o login com
/// o e-mail e a senha digitados (RM12).
final class RegistrationSuccess extends RegistrationResult {
  const new();

  @override
  bool operator ==(Object other) => other is RegistrationSuccess;

  @override
  int get hashCode => (RegistrationSuccess).hashCode;

  @override
  String toString() => 'RegistrationSuccess()';
}

/// A API recusou campos do cadastro: o 400, com a mensagem de cada campo do `details`, ou o 409,
/// com o e-mail ou o CPF que já tem conta ([alreadyInUse]). As mensagens são as da API, para
/// mostrar embaixo de cada campo.
final class RegistrationFieldErrors extends RegistrationResult {
  const new(this.errors, {this.alreadyInUse});

  final Map<RegistrationField, String> errors;

  /// No 409, o campo que já tem conta: o e-mail ou o CPF. `null` no 400.
  final RegistrationField? alreadyInUse;

  /// A mensagem do [field], ou `null` quando a API aceitou o campo.
  String? messageFor(RegistrationField field) => errors[field];

  @override
  bool operator ==(Object other) =>
      other is RegistrationFieldErrors &&
      other.alreadyInUse == alreadyInUse &&
      other.errors.length == errors.length &&
      errors.entries.every((entry) => other.errors[entry.key] == entry.value);

  @override
  int get hashCode => Object.hash(
    alreadyInUse,
    Object.hashAllUnordered([
      for (final MapEntry(:key, :value) in errors.entries) Object.hash(key, value),
    ]),
  );

  @override
  String toString() => 'RegistrationFieldErrors($errors, alreadyInUse: ${alreadyInUse?.name})';
}

/// Muitos cadastros do mesmo IP (429): a API recusa até o fim do [retryAfter], e o "Criar conta"
/// fica desativado com a contagem regressiva, como o "Entrar" (RM04).
final class RegistrationRateLimited extends RegistrationResult {
  const new({required this.retryAfter});

  /// A espera quando a API não manda o `Retry-After`: a janela inteira do limite, de 1 minuto.
  static const defaultRetryAfter = Duration(minutes: 1);

  final Duration retryAfter;

  @override
  bool operator ==(Object other) =>
      other is RegistrationRateLimited && other.retryAfter == retryAfter;

  @override
  int get hashCode => retryAfter.hashCode;

  @override
  String toString() => 'RegistrationRateLimited(retryAfter: $retryAfter)';
}
