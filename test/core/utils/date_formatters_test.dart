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

  group('maskedDateToIso', () {
    test('deve converter a data da tela no formato da API', () {
      expect(maskedDateToIso('20/05/1990'), '1990-05-20');
      expect(maskedDateToIso('20051990'), '1990-05-20');
    });

    test('não deve conferir se a data existe: isso é do domínio', () {
      expect(maskedDateToIso('31/02/2001'), '2001-02-31');
    });

    for (final text in ['', '20/05', '20/05/19', '20/05/19900']) {
      test('deve devolver null sem os 8 dígitos: "$text"', () {
        expect(maskedDateToIso(text), isNull);
      });
    }
  });

  group('DateInputFormatter', () {
    const sut = DateInputFormatter();

    test('deve formatar no dd/mm/aaaa, com até 8 dígitos', () {
      expect(sut.maxDigits, 8);
      expect(
        [
          for (final digits in ['2', '20', '200', '2005', '20051', '20051990']) sut.format(digits),
        ],
        ['2', '20', '20/0', '20/05', '20/05/1', '20/05/1990'],
      );
    });
  });
}
