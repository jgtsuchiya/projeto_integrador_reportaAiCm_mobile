import 'package:intl/intl.dart';
import 'package:reportaai_cm/core/utils/masked_input_formatter.dart';

final _date = DateFormat('dd/MM/yyyy', 'pt_BR');
final _dateTime = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
final _monthYear = DateFormat("MMMM 'de' y", 'pt_BR');

/// Data no formato do app: `20/05/1990`. Não converte o fuso: formata a data como ela está.
String formatDate(DateTime date) => _date.format(date);

/// Data e hora no formato do app: `20/05/1990 14:30`. Não converte o fuso: para mostrar uma data
/// da API (em UTC) no horário do aparelho, passe o `toLocal()`.
String formatDateTime(DateTime dateTime) => _dateTime.format(dateTime);

/// O mês por extenso e o ano: `outubro de 2026`. Não converte o fuso: para uma data da API (em
/// UTC), passe o `toLocal()`, senão o mês pode virar no último dia dele.
String formatMonthYear(DateTime date) => _monthYear.format(date);

/// A data digitada no campo com a máscara (`20/05/1990`) no formato da API, `1990-05-20`. Devolve
/// `null` enquanto a data não tem os 8 dígitos. Não confere se a data existe: isso é do domínio.
String? maskedDateToIso(String text) {
  final digits = digitsOnly(text);
  if (digits.length != 8) return null;

  return '${digits.substring(4)}-${digits.substring(2, 4)}-${digits.substring(0, 2)}';
}

/// A máscara do campo de data enquanto o usuário digita: `dd/mm/aaaa`. Para enviar, converta com
/// o [maskedDateToIso].
final class DateInputFormatter extends MaskedDigitsInputFormatter {
  const new() : super(maxDigits: 8);

  @override
  String format(String digits) => applyDigitMask(digits, '##/##/####');
}
