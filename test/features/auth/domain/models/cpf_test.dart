import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/auth/domain/models/cpf.dart';

void main() {
  // Os mesmos casos do value object `Cpf` do backend (cpf.spec.ts).
  group('isValidCpf', () {
    for (final (description, cpf) in [
      ('só com dígitos', '52998224725'),
      ('com a máscara e os espaços das pontas (RN07)', ' 111.444.777-35 '),
      ('com o dígito verificador calculado 10, que vira 0', '123.456.789-09'),
    ]) {
      test('deve aceitar o CPF $description', () {
        expect(isValidCpf(cpf), isTrue);
      });
    }

    for (final (description, cpf) in [
      ('o primeiro dígito verificador errado', '52998224735'),
      ('o segundo dígito verificador errado', '52998224726'),
      ('uma sequência repetida', '11111111111'),
      ('uma sequência de zeros', '000.000.000-00'),
      ('menos de 11 dígitos', '5299822472'),
      ('mais de 11 dígitos', '529982247250'),
      ('letras', '5299822472a'),
      ('a máscara incompleta', '529.982.24725'),
      ('nada', ''),
    ]) {
      test('deve recusar o CPF com $description', () {
        expect(isValidCpf(cpf), isFalse);
      });
    }

    test('deve recusar todas as sequências repetidas, de 0 a 9', () {
      for (var digit = 0; digit <= 9; digit++) {
        expect(isValidCpf('$digit' * 11), isFalse, reason: '$digit');
      }
    });
  });
}
