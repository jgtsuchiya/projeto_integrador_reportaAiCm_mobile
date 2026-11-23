import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/auth/domain/models/password.dart';

void main() {
  // Os mesmos casos do value object `Password` do backend (password.spec.ts).
  group('validatePassword', () {
    for (final (description, password) in [
      ('o mínimo de 8 caracteres', 'abcdef12'),
      ('o máximo de 128 caracteres', 'a1${'x' * 126}'),
      ('letras com acento', 'ção12345'),
      ('espaços e símbolos', ' senha 1! '),
    ]) {
      test('deve aceitar a senha com $description (RN08)', () {
        expect(validatePassword(password), isNull);
      });
    }

    for (final (description, password) in [
      ('menos de 8 caracteres', 'abcde12'),
      ('mais de 128 caracteres', 'a1${'x' * 127}'),
      ('nada', ''),
    ]) {
      test('deve recusar a senha com $description (RN08)', () {
        expect(validatePassword(password), 'A senha deve ter de 8 a 128 caracteres.');
      });
    }

    for (final (description, password) in [
      ('sem número', 'abcdefgh'),
      ('sem letra', '12345678'),
      ('só com símbolos e números', r'!@#$1234'),
    ]) {
      test('deve recusar a senha $description (RN08)', () {
        expect(validatePassword(password), 'A senha deve ter pelo menos uma letra e um número.');
      });
    }

    test('deve conferir o tamanho antes da letra e do número, como a API', () {
      expect(validatePassword('abc'), PasswordMessages.length);
    });
  });

  group('PasswordRule', () {
    test('deve ter os itens da RN08, na ordem da tela', () {
      expect(
        [for (final rule in PasswordRule.values) rule.label],
        ['De 8 a 128 caracteres', 'Pelo menos uma letra', 'Pelo menos um número'],
      );
    });

    test('deve marcar só os itens que a senha cumpre', () {
      expect([for (final rule in PasswordRule.values) rule.isMetBy('abc')], [false, true, false]);
      expect(
        [for (final rule in PasswordRule.values) rule.isMetBy('12345678')],
        [true, false, true],
      );
      expect(
        [for (final rule in PasswordRule.values) rule.isMetBy('senha-forte-1')],
        [true, true, true],
      );
    });

    test('deve aceitar a letra de qualquer alfabeto', () {
      expect(PasswordRule.letter.isMetBy('ж1234567'), isTrue);
      expect(PasswordRule.letter.isMetBy('é'), isTrue);
    });
  });
}
