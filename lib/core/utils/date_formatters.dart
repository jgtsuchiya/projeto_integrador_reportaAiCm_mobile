import 'package:intl/intl.dart';

final _date = DateFormat('dd/MM/yyyy', 'pt_BR');
final _dateTime = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

/// Data no formato do app: `20/05/1990`. Não converte o fuso: formata a data como ela está.
String formatDate(DateTime date) => _date.format(date);

/// Data e hora no formato do app: `20/05/1990 14:30`. Não converte o fuso: para mostrar uma data
/// da API (em UTC) no horário do aparelho, passe o `toLocal()`.
String formatDateTime(DateTime dateTime) => _dateTime.format(dateTime);
