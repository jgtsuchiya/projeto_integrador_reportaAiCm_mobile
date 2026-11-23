import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/auth/domain/models/phone.dart';

void main() {
  // Os mesmos casos do value object `Phone` do backend (phone.spec.ts).
  group('isValidPhone', () {
    for (final (description, phone) in [
      ('o celular só com dígitos', '43999998888'),
      ('o celular com a máscara', '(43) 99999-8888'),
      ('o fixo', '4332221111'),
      ('o fixo com a máscara', '(11) 3222-1111'),
      ('os espaços das pontas', ' (44) 99999-8888 '),
    ]) {
      test('deve aceitar $description', () {
        expect(isValidPhone(phone), isTrue);
      });
    }

    for (final (description, phone) in [
      ('sem o DDD', '999998888'),
      ('o DDD com zero', '03999998888'),
      ('o celular sem o 9 do começo', '43899998888'),
      ('o fixo começando com 9 e 8 dígitos', '4392221111'),
      ('o fixo começando com 1', '4312221111'),
      ('dígitos a mais', '439999988881'),
      ('letras', '43 9999-abcd'),
      ('nada', ''),
    ]) {
      test('deve recusar $description', () {
        expect(isValidPhone(phone), isFalse);
      });
    }
  });
}
