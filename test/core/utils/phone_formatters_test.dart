import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/utils/phone_formatters.dart';

void main() {
  group('formatPhone', () {
    test('deve formatar o celular, com 11 dígitos', () {
      expect(formatPhone('44999998888'), '(44) 99999-8888');
    });

    test('deve formatar o fixo, com 10 dígitos', () {
      expect(formatPhone('4433334444'), '(44) 3333-4444');
    });

    for (final phone in ['999998888', '449999988880', '(44) 99999-8888', '']) {
      test('deve devolver como veio o telefone fora do formato da API: "$phone"', () {
        expect(formatPhone(phone), phone);
      });
    }
  });

  group('PhoneInputFormatter', () {
    const sut = PhoneInputFormatter();

    test('deve formatar o fixo até 10 dígitos e o celular com 11', () {
      expect(sut.maxDigits, 11);
      expect(sut.format('4433334444'), '(44) 3333-4444');
      expect(sut.format('44999998888'), '(44) 99999-8888');
    });

    test('deve formatar enquanto o usuário digita', () {
      expect(
        [
          for (final digits in ['4', '44', '449', '449999', '4499999', '4499999888'])
            sut.format(digits),
        ],
        ['(4', '(44', '(44) 9', '(44) 9999', '(44) 9999-9', '(44) 9999-9888'],
      );
    });

    for (final pasted in ['44999998888', '(44) 99999-8888', '44 99999 8888']) {
      test('deve aceitar o celular colado "$pasted", com ou sem pontuação', () {
        final result = sut.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
            text: pasted,
            selection: TextSelection.collapsed(offset: pasted.length),
          ),
        );

        expect(result.text, '(44) 99999-8888');
        expect(result.selection, const TextSelection.collapsed(offset: 15));
      });
    }

    for (final filled in [
      '+55 44 99999-8888',
      '5544999998888',
      '044 99999-8888',
      '0044999998888',
    ]) {
      test('deve tirar o código do país ou o 0 do número preenchido de uma vez: "$filled"', () {
        final result = sut.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
            text: filled,
            selection: TextSelection.collapsed(offset: filled.length),
          ),
        );

        expect(result.text, '(44) 99999-8888');
      });
    }

    test('não deve tirar o DDD 55 de quem digita no campo já preenchido', () {
      const full = TextEditingValue(
        text: '(55) 99999-8888',
        selection: TextSelection.collapsed(offset: 15),
      );

      final result = sut.formatEditUpdate(
        full,
        const TextEditingValue(
          text: '(55) 99999-88881',
          selection: TextSelection.collapsed(offset: 16),
        ),
      );

      expect(result, full);
    });
  });
}
