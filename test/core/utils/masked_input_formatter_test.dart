import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/utils/cpf_formatters.dart';
import 'package:reportaai_cm/core/utils/masked_input_formatter.dart';

/// O texto com o cursor na [cursor] (no fim, se não for passado).
TextEditingValue _value(String text, [int? cursor]) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: cursor ?? text.length),
);

void main() {
  group('digitsOnly', () {
    test('deve tirar tudo o que não é dígito', () {
      expect(digitsOnly('529.982.247-25'), '52998224725');
      expect(digitsOnly('(44) 99999-8888'), '44999998888');
      expect(digitsOnly(' 20/05/1990 '), '20051990');
      expect(digitsOnly(''), '');
    });
  });

  group('applyDigitMask', () {
    test('deve pôr a pontuação só antes de um dígito', () {
      expect(applyDigitMask('', '###.###'), '');
      expect(applyDigitMask('529', '###.###'), '529');
      expect(applyDigitMask('5299', '###.###'), '529.9');
      expect(applyDigitMask('4', '(##) ####'), '(4');
    });

    test('deve deixar de fora os dígitos que sobram do padrão', () {
      expect(applyDigitMask('5299822', '###.###'), '529.982');
    });
  });

  // O CPF é o exemplo: a regra vale para o telefone e a data, que só mudam o padrão.
  group('MaskedDigitsInputFormatter', () {
    const sut = CpfInputFormatter();

    TextEditingValue edit(TextEditingValue oldValue, TextEditingValue newValue) =>
        sut.formatEditUpdate(oldValue, newValue);

    test('deve formatar enquanto o usuário digita, dígito a dígito', () {
      var value = TextEditingValue.empty;
      final typed = <String>[];

      for (final digit in '52998224725'.split('')) {
        value = edit(value, _value('${value.text}$digit'));
        typed.add(value.text);
      }

      expect(typed, [
        '5',
        '52',
        '529',
        '529.9',
        '529.98',
        '529.982',
        '529.982.2',
        '529.982.24',
        '529.982.247',
        '529.982.247-2',
        '529.982.247-25',
      ]);
      expect(value.selection, const TextSelection.collapsed(offset: 14));
    });

    for (final pasted in ['52998224725', '529.982.247-25', ' 529 982 247 25 ', '529982.24725']) {
      test('deve aceitar o valor colado "$pasted", com ou sem pontuação', () {
        final result = edit(TextEditingValue.empty, _value(pasted));

        expect(result.text, '529.982.247-25');
        expect(result.selection, const TextSelection.collapsed(offset: 14));
      });
    }

    test('deve cortar o valor colado maior que o campo', () {
      expect(edit(TextEditingValue.empty, _value('529982247251234')).text, '529.982.247-25');
    });

    test('não deve aceitar mais um dígito no campo completo', () {
      final full = _value('529.982.247-25');

      expect(edit(full, _value('529.982.247-251')), full);
      expect(edit(full, _value('5299.982.247-25', 4)), full);
    });

    test('deve manter o cursor depois do dígito digitado no meio', () {
      // "529.|982": digita 1 entre o ponto e o 9.
      final result = edit(_value('529.982', 4), _value('529.1982', 5));

      expect(result.text, '529.198.2');
      expect(result.selection, const TextSelection.collapsed(offset: 5));
    });

    test('deve manter o cursor no lugar ao apagar um dígito do meio', () {
      // "529.9|82": apaga o 9 depois do ponto.
      final result = edit(_value('529.982.247-25', 5), _value('529.82.247-25', 4));

      expect(result.text, '529.822.472-5');
      expect(result.selection, const TextSelection.collapsed(offset: 3));
    });

    test('deve apagar o dígito antes da pontuação no "apagar" logo depois dela', () {
      // "529.982.247-|25": o "apagar" tira o traço, que a máscara poria de volta.
      final result = edit(_value('529.982.247-25', 12), _value('529.982.24725', 11));

      expect(result.text, '529.982.242-5');
      expect(result.selection, const TextSelection.collapsed(offset: 10));
    });

    test('deve apagar o dígito depois da pontuação no "apagar para a frente" antes dela', () {
      // "529|.982": o delete tira o ponto.
      final result = edit(_value('529.982', 3), _value('529982', 3));

      expect(result.text, '529.82');
      expect(result.selection, const TextSelection.collapsed(offset: 3));
    });

    test('deve esvaziar o campo ao apagar o último dígito', () {
      expect(edit(_value('5'), _value('')), _value(''));
    });

    test('deve apagar a seleção inteira, com a pontuação', () {
      final selected = _value('529.982.247-25')
          .copyWith(selection: const TextSelection(baseOffset: 3, extentOffset: 8));

      // "529[.982.]247-25": a seleção sai, e os dígitos que sobram se juntam.
      final result = edit(selected, _value('529247-25', 3));

      expect(result.text, '529.247.25');
      expect(result.selection, const TextSelection.collapsed(offset: 3));
    });

    test('deve formatar o texto sem cursor, com o cursor no fim', () {
      final result = edit(
        TextEditingValue.empty,
        // Sem a seleção, o padrão do TextEditingValue: o cursor em -1.
        const TextEditingValue(text: '52998224725'),
      );

      expect(result.text, '529.982.247-25');
      expect(result.selection.baseOffset, 14);
    });
  });
}
