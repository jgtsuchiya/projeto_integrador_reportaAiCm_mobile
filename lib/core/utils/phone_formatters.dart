import 'package:flutter/services.dart';
import 'package:reportaai_cm/core/utils/masked_input_formatter.dart';

/// O DDD, o começo do número (4 dígitos no fixo e 5 no celular) e os 4 dígitos do fim.
final _phoneParts = RegExp(r'^(\d{2})(\d{4,5})(\d{4})$');

/// O telefone com o DDD entre parênteses: `(44) 99999-8888` no celular (11 dígitos) e
/// `(44) 3333-4444` no fixo (10 dígitos). Recebe só os dígitos, como a API os devolve. Fora
/// desses formatos, devolve o telefone como veio.
String formatPhone(String phone) => switch (_phoneParts.firstMatch(phone)) {
  final match? => '(${match[1]}) ${match[2]}-${match[3]}',
  null => phone,
};

/// A máscara do campo de telefone enquanto o usuário digita: `(00) 0000-0000` até 10 dígitos (o
/// fixo) e `(00) 00000-0000` com 11 (o celular). Para enviar, tire a máscara com o `digitsOnly`.
///
/// O número que chega de uma vez no campo vazio (colado ou preenchido pelo gerenciador do
/// aparelho) pode vir com o código do país (`+55`) ou com o 0 da ligação interurbana: com mais de
/// 11 dígitos, os dois saem do começo, e fica o DDD e o número.
final class PhoneInputFormatter extends MaskedDigitsInputFormatter {
  const new() : super(maxDigits: 11);

  static final _prefix = RegExp('^(55|0+)');

  @override
  String format(String digits) =>
      applyDigitMask(digits, digits.length > 10 ? '(##) #####-####' : '(##) ####-####');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = digitsOnly(newValue.text);
    if (oldValue.text.isNotEmpty || digits.length <= maxDigits) {
      return super.formatEditUpdate(oldValue, newValue);
    }

    final national = digits.replaceFirst(_prefix, '');
    return super.formatEditUpdate(
      oldValue,
      TextEditingValue(
        text: national,
        selection: TextSelection.collapsed(offset: national.length),
      ),
    );
  }
}
