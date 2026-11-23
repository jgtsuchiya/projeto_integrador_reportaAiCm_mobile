import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/auth/domain/models/birth_date.dart';

void main() {
  // O mesmo "agora" do birth-date.spec.ts do backend.
  final now = DateTime.utc(2026, 9, 27, 12);

  // Os mesmos casos do value object `BirthDate` do backend (birth-date.spec.ts).
  group('isValidBirthDate', () {
    for (final (description, date) in [
      ('uma data no passado, com os espaços das pontas', ' 1990-05-20 '),
      ('a data de ontem', '2026-09-26'),
      ('29 de fevereiro num ano bissexto', '2000-02-29'),
      ('o primeiro dia de 1900', '1900-01-01'),
    ]) {
      test('deve aceitar $description', () {
        expect(isValidBirthDate(date, now: now), isTrue);
      });
    }

    for (final date in ['20/05/1990', '1990-5-20', '1990-05-20T00:00:00Z', 'abc', '']) {
      test('deve recusar o formato "$date"', () {
        expect(isCalendarDate(date), isFalse);
        expect(isValidBirthDate(date, now: now), isFalse);
      });
    }

    for (final date in ['2001-02-29', '1990-02-30', '1990-13-01', '1990-04-31', '1990-00-10']) {
      test('deve recusar a data que não existe "$date"', () {
        expect(isCalendarDate(date), isFalse);
        expect(isValidBirthDate(date, now: now), isFalse);
      });
    }

    for (final date in ['2026-09-27', '2026-09-28', '2030-01-01']) {
      test('deve recusar a data de hoje ou futura "$date"', () {
        expect(isCalendarDate(date), isTrue);
        expect(isValidBirthDate(date, now: now), isFalse);
      });
    }

    test('deve recusar as datas antes de 1900', () {
      expect(isValidBirthDate('1899-12-31', now: now), isFalse);
    });

    test('deve usar o "hoje" em UTC, como a API', () {
      // 21h30 de 26/09 em Brasília (UTC-3) já é 27/09 em UTC: a API aceita o dia 26.
      final evening = DateTime.utc(2026, 9, 27, 0, 30);

      expect(isValidBirthDate('2026-09-26', now: evening), isTrue);
      expect(isValidBirthDate('2026-09-27', now: evening), isFalse);
    });

    test('deve usar o relógio do aparelho quando o "agora" não é passado', () {
      expect(isValidBirthDate('1990-05-20'), isTrue);
      expect(isValidBirthDate('2999-01-01'), isFalse);
    });
  });
}
