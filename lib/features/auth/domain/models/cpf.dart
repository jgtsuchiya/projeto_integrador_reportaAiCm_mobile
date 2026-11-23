// As regras do CPF são as mesmas do value object `Cpf` do backend (RN07), para o app recusar antes
// de enviar só o que a API também recusaria.
final _formatted = RegExp(r'^\d{3}\.\d{3}\.\d{3}-\d{2}$');
final _digits = RegExp(r'^\d{11}$');
final _repeated = RegExp(r'^(\d)\1{10}$');
final _nonDigits = RegExp(r'\D');

/// Se o [cpf] é válido: com a máscara completa (`529.982.247-25`) ou só com os 11 dígitos, sem
/// os espaços das pontas, e com os dois dígitos verificadores certos. As sequências repetidas,
/// como `111.111.111-11`, passam no cálculo, mas não são CPFs.
bool isValidCpf(String cpf) {
  final value = cpf.trim();
  if (!_formatted.hasMatch(value) && !_digits.hasMatch(value)) return false;

  final digits = value.replaceAll(_nonDigits, '');
  if (_repeated.hasMatch(digits)) return false;

  final numbers = [for (final digit in digits.split('')) int.parse(digit)];

  return _checkDigit(numbers.sublist(0, 9)) == numbers[9] &&
      _checkDigit(numbers.sublist(0, 10)) == numbers[10];
}

/// O dígito verificador dos [numbers]: os pesos começam em `length + 1` e descem até 2. O resto
/// 10 vira 0.
int _checkDigit(List<int> numbers) {
  final firstWeight = numbers.length + 1;
  var sum = 0;
  for (var index = 0; index < numbers.length; index++) {
    sum += numbers[index] * (firstWeight - index);
  }
  final rest = sum * 10 % 11;

  return rest == 10 ? 0 : rest;
}
