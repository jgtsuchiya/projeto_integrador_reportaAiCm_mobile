import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/utils/date_formatters.dart';

void main() {
  group('formatDate', () {
    test('deve formatar em dd/MM/yyyy', () {
      expect(formatDate(DateTime(1990, 5, 20)), '20/05/1990');
    });

    test('não deve converter o fuso de uma data em UTC', () {
      expect(formatDate(DateTime.utc(1990, 5, 20)), '20/05/1990');
    });
  });

  group('formatDateTime', () {
    test('deve formatar em dd/MM/yyyy HH:mm, com 24 horas', () {
      expect(formatDateTime(DateTime(2026, 10, 20, 14, 5)), '20/10/2026 14:05');
    });
  });

  group('formatMonthYear', () {
    test('deve formatar o mês por extenso, em minúsculas, e o ano', () {
      expect(formatMonthYear(DateTime(2026, 10, 4)), 'outubro de 2026');
    });

    test('deve formatar os meses com acento e de uma palavra só', () {
      expect(formatMonthYear(DateTime(2027, 3)), 'março de 2027');
      expect(formatMonthYear(DateTime(2027, 5)), 'maio de 2027');
    });

    test('não deve converter o fuso de uma data em UTC', () {
      expect(formatMonthYear(DateTime.utc(2026, 11)), 'novembro de 2026');
    });
  });
}
