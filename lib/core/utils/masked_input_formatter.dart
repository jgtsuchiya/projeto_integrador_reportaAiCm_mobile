import 'dart:math' as math;

import 'package:flutter/services.dart';

final _nonDigits = RegExp(r'\D');

/// Só os dígitos do [text], sem a máscara: `529.982.247-25` vira `52998224725`. É o formato em
/// que o app envia o CPF e o telefone para a API.
String digitsOnly(String text) => text.replaceAll(_nonDigits, '');

/// Os [digits] no [pattern], em que cada `#` é um dígito: `52998` no `###.###.###-##` vira
/// `529.98`. A pontuação só entra antes de um dígito (`529`, e não `529.`), para o "apagar" não
/// esbarrar nela. Os dígitos que sobram do [pattern] ficam de fora.
String applyDigitMask(String digits, String pattern) {
  final buffer = StringBuffer();
  var next = 0;

  for (final char in pattern.split('')) {
    if (next >= digits.length) break;
    buffer.write(char == '#' ? digits[next++] : char);
  }

  return buffer.toString();
}

/// A máscara de um campo só de dígitos, como o CPF, o telefone e a data. A cada mudança, o campo
/// fica só com os dígitos e é formatado de novo pelo [format]: colar o valor com ou sem a
/// pontuação dá o mesmo resultado.
///
/// O cursor fica depois do mesmo dígito em que estava, e não pula para o fim. O "apagar" logo
/// depois da pontuação apaga também o dígito antes dela: sozinho, ele só tiraria a pontuação, que
/// a máscara põe de volta, e o campo pareceria travado.
abstract class MaskedDigitsInputFormatter extends TextInputFormatter {
  const new({required this.maxDigits});

  /// Os dígitos que o campo aceita. Um dígito a mais num campo completo não entra, e um valor
  /// colado maior que isso é cortado.
  final int maxDigits;

  /// Os [digits], com no máximo [maxDigits], com a pontuação da máscara.
  String format(String digits);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final oldDigits = digitsOnly(oldValue.text);
    var digits = digitsOnly(newValue.text);
    final selection = newValue.selection;
    var cursor = selection.isValid
        ? digitsOnly(newValue.text.substring(0, selection.end)).length
        : digits.length;

    final removedOnlyPunctuation =
        newValue.text.length < oldValue.text.length &&
        digits == oldDigits &&
        oldValue.selection.isCollapsed &&
        selection.isCollapsed;
    if (removedOnlyPunctuation) {
      if (selection.end < oldValue.selection.end) {
        // O "apagar" (backspace): sai o dígito antes da pontuação.
        if (cursor > 0) digits = digits.replaceRange(cursor - 1, cursor, '');
        cursor = math.max(0, cursor - 1);
      } else if (cursor < digits.length) {
        // O "apagar para a frente" (delete): sai o dígito depois da pontuação.
        digits = digits.replaceRange(cursor, cursor + 1, '');
      }
    }

    if (digits.length > maxDigits) {
      if (oldDigits.length >= maxDigits && oldValue.selection.isCollapsed) return oldValue;

      digits = digits.substring(0, maxDigits);
      cursor = math.min(cursor, maxDigits);
    }

    final text = format(digits);

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: _offsetAfterDigits(text, cursor)),
    );
  }
}

/// A posição logo depois do [count]-ésimo dígito do [text], ou o começo, sem nenhum.
int _offsetAfterDigits(String text, int count) {
  if (count <= 0) return 0;

  var seen = 0;
  for (var index = 0; index < text.length; index++) {
    if (_isDigit(text.codeUnitAt(index)) && ++seen == count) return index + 1;
  }

  return text.length;
}

bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;
