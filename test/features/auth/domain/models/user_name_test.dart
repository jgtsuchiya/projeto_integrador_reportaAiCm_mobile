import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/auth/domain/models/user_name.dart';

void main() {
  // As mesmas regras do `userNameSchema` do backend.
  group('isValidUserName', () {
    test('deve aceitar o nome de 1 a 120 caracteres, sem os espaços das pontas', () {
      expect(isValidUserName('M'), isTrue);
      expect(isValidUserName('  Maria da Silva  '), isTrue);
      expect(isValidUserName('a' * 120), isTrue);
      expect(isValidUserName('  ${'a' * 120}  '), isTrue);
    });

    test('deve recusar o nome vazio ou só com espaços', () {
      expect(isValidUserName(''), isFalse);
      expect(isValidUserName('   '), isFalse);
    });

    test('deve recusar o nome com mais de 120 caracteres', () {
      expect(isValidUserName('a' * 121), isFalse);
    });
  });
}
