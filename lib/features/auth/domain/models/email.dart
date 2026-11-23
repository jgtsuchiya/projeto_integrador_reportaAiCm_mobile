// As regras do e-mail são as mesmas do value object `Email` do backend, para o app recusar antes de
// enviar só o que a API também recusaria (RN02).
const _maxLength = 254;
const _maxLocalPartLength = 64;
final _pattern = RegExp(r'^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$');

/// As mensagens do campo de e-mail antes de enviar, as mesmas no login (RM05), no cadastro (RM11)
/// e no "Esqueci minha senha".
abstract final class EmailMessages {
  static const missing = 'Informe o e-mail.';
  static const invalid = 'E-mail inválido.';
}

/// O e-mail como a API o guarda: sem os espaços das pontas e em minúsculas (RN02).
String normalizeEmail(String email) => email.trim().toLowerCase();

/// A mensagem do campo de e-mail: vazio ou fora do formato. `null` quando ele pode ser enviado.
String? validateEmail(String email) {
  if (email.trim().isEmpty) return EmailMessages.missing;
  if (!isValidEmail(email)) return EmailMessages.invalid;

  return null;
}

/// Se o [email] está no formato que a API aceita, conferido já normalizado: uma parte local, o `@`
/// e um domínio com pelo menos um ponto, sem espaços, com até 254 caracteres e até 64 antes do `@`.
bool isValidEmail(String email) {
  final value = normalizeEmail(email);
  final localPart = value.split('@').first;

  return value.length <= _maxLength &&
      localPart.length <= _maxLocalPartLength &&
      _pattern.hasMatch(value);
}
