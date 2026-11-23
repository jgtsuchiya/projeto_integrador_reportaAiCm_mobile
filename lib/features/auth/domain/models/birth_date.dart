// As regras da data de nascimento são as mesmas do value object `BirthDate` do backend, para o app
// recusar antes de enviar só o que a API também recusaria.
final _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
const _minDate = '1900-01-01';

/// Se o [value] é uma data no formato da API (`AAAA-MM-DD`, sem os espaços das pontas) e existe
/// no calendário. Recusa as datas que o `DateTime` corrigiria sozinho, como `2001-02-29` (vira
/// `2001-03-01`).
bool isCalendarDate(String value) {
  final match = _isoDate.firstMatch(value.trim());
  if (match == null) return false;

  final [year, month, day] = [for (var group = 1; group <= 3; group++) int.parse(match[group]!)];
  final date = DateTime.utc(year, month, day);

  return date.year == year && date.month == month && date.day == day;
}

/// Se o [value] (`AAAA-MM-DD`) é uma data de nascimento que a API aceita: existe, é de 1900 em
/// diante e está no passado. Como na API, "hoje" é a data em UTC do [now] (o relógio do aparelho,
/// se não for passado): no Brasil, a data muda às 21h.
bool isValidBirthDate(String value, {DateTime? now}) {
  if (!isCalendarDate(value)) return false;

  final date = value.trim();
  final today = (now ?? DateTime.now()).toUtc().toIso8601String().substring(0, 10);

  // Comparação das strings ISO: a ordem alfabética é a mesma da cronológica.
  return date.compareTo(_minDate) >= 0 && date.compareTo(today) < 0;
}
