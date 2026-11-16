import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/auth/domain/models/email.dart';

void main() {
  group('normalizeEmail', () {
    test('deve tirar os espaços das pontas e passar para minúsculas (RN02)', () {
      expect(normalizeEmail('  Maria.Silva@Exemplo.COM '), 'maria.silva@exemplo.com');
    });
  });

  // Os mesmos casos do value object `Email` do backend.
  group('isValidEmail', () {
    for (final email in [
      'maria+reports@example.com',
      'a@b.co',
      'deleted+id@reportaai.invalid',
      '  Maria.Silva@Exemplo.COM ',
    ]) {
      test('deve aceitar "$email"', () {
        expect(isValidEmail(email), isTrue);
      });
    }

    for (final email in [
      '',
      'maria',
      'maria@',
      '@example.com',
      'maria@example',
      'maria@@example.com',
      'maria silva@example.com',
      'maria@example..com',
      'maria@.example.com',
    ]) {
      test('deve recusar "$email"', () {
        expect(isValidEmail(email), isFalse);
      });
    }

    test('deve recusar o e-mail com mais de 254 caracteres', () {
      expect(isValidEmail('maria@${'a' * 250}.com'), isFalse);
    });

    test('deve recusar a parte local com mais de 64 caracteres', () {
      expect(isValidEmail('${'a' * 65}@example.com'), isFalse);
      expect(isValidEmail('${'a' * 64}@example.com'), isTrue);
    });
  });
}
