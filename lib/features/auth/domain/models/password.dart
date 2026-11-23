// A política de senha da RN08, a mesma do value object `Password` do backend. Fica num lugar só: o
// cadastro e a troca de senha usam as mesmas regras e as mesmas mensagens.
const passwordMinLength = 8;
const passwordMaxLength = 128;

final _letter = RegExp(r'\p{L}', unicode: true);
final _digit = RegExp(r'\d');

/// As mensagens do campo de senha: a do campo vazio, a mesma do login (RM05), e as da API para a
/// senha fora da política (RN08).
abstract final class PasswordMessages {
  static const missing = 'Informe a senha.';
  static const length = 'A senha deve ter de $passwordMinLength a $passwordMaxLength caracteres.';
  static const characters = 'A senha deve ter pelo menos uma letra e um número.';
}

/// Cada item da política de senha (RN08), para a tela mostrar a regra e marcar o que a senha já
/// cumpre.
enum PasswordRule {
  /// De 8 a 128 caracteres, contados como na API (unidades UTF-16 do JavaScript e do Dart).
  length('De $passwordMinLength a $passwordMaxLength caracteres'),

  /// Pelo menos uma letra, de qualquer alfabeto, com ou sem acento.
  letter('Pelo menos uma letra'),

  /// Pelo menos um número, de 0 a 9.
  number('Pelo menos um número');

  new(this.label);

  final String label;

  bool isMetBy(String password) => switch (this) {
    PasswordRule.length =>
      password.length >= passwordMinLength && password.length <= passwordMaxLength,
    PasswordRule.letter => _letter.hasMatch(password),
    PasswordRule.number => _digit.hasMatch(password),
  };
}

/// A mensagem da API para a [password] fora da política (RN08), na mesma ordem em que a API
/// confere: primeiro o tamanho, depois a letra e o número. `null` quando a senha cumpre a
/// política. A senha é conferida como foi digitada, com os espaços.
String? validatePassword(String password) {
  if (!PasswordRule.length.isMetBy(password)) return PasswordMessages.length;
  if (!PasswordRule.letter.isMetBy(password) || !PasswordRule.number.isMetBy(password)) {
    return PasswordMessages.characters;
  }

  return null;
}
