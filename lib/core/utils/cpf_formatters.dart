import 'package:reportaai_cm/core/utils/masked_input_formatter.dart';

final _cpfDigits = RegExp(r'^\d{11}$');

/// O CPF mascarado, como no painel (RN12): `***.982.247-**`, só com os seis dígitos do meio.
/// Recebe o CPF só com dígitos, como a API o devolve. Fora desse formato, mascara todos os
/// dígitos: o CPF completo nunca aparece na tela (RM09).
String maskCpf(String cpf) => _cpfDigits.hasMatch(cpf)
    ? '***.${cpf.substring(3, 6)}.${cpf.substring(6, 9)}-**'
    : '***.***.***-**';

/// A máscara do campo de CPF enquanto o usuário digita: `000.000.000-00`. Para enviar, tire a
/// máscara com o `digitsOnly`.
final class CpfInputFormatter extends MaskedDigitsInputFormatter {
  const new() : super(maxDigits: 11);

  @override
  String format(String digits) => applyDigitMask(digits, '###.###.###-##');
}
