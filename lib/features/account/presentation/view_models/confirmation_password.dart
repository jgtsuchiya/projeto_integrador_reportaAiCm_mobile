import 'package:reportaai_cm/core/network/api_exception.dart';

/// As mensagens da senha atual, que confirma a troca de senha, a verificação em duas etapas e a
/// exclusão da conta (RM15).
abstract final class ConfirmationPasswordMessages {
  static const missing = 'Informe a senha atual.';

  /// A mensagem do app para a senha incorreta. A da API ("Senha incorreta.") não diz qual senha.
  static const incorrect = 'Senha atual incorreta.';
}

/// Se o [error] é a senha de confirmação incorreta: o 422 da API com o campo da senha
/// (`currentPassword` ou `password`). Desde a T8 do backend, a senha errada nunca é um 401, e não
/// leva ao login como sessão expirada (RM15).
bool isIncorrectPassword(Object error) => switch (error) {
  BusinessRuleException(field: 'currentPassword' || 'password') => true,
  _ => false,
};
