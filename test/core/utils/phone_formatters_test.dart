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
}
