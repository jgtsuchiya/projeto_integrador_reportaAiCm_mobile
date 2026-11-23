// As regras do telefone são as mesmas do value object `Phone` do backend, para o app recusar antes
// de enviar só o que a API também recusaria.
final _allowedCharacters = RegExp(r'^[\d\s()+-]+$');
final _nonDigits = RegExp(r'\D');

/// O DDD (dois dígitos de 1 a 9) e o número: o celular com 9 dígitos, começando por 9, ou o fixo
/// com 8, começando de 2 a 5.
final _pattern = RegExp(r'^[1-9]{2}(9\d{8}|[2-5]\d{7})$');

/// Se o [phone] é válido: o DDD e o número, com ou sem a máscara (`(44) 99999-8888`), sem os
/// espaços das pontas. Além dos dígitos, só aceita espaços, parênteses, `+` e `-`.
bool isValidPhone(String phone) {
  final value = phone.trim();
  if (!_allowedCharacters.hasMatch(value)) return false;

  return _pattern.hasMatch(value.replaceAll(_nonDigits, ''));
}
