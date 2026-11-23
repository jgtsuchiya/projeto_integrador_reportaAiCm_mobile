import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/auth/domain/models/client_registration.dart';

const _registration = ClientRegistration(
  name: 'Maria da Silva',
  email: 'maria.silva@exemplo.com',
  password: 'senha-forte-1',
  cpf: '52998224725',
  phone: '44999998888',
  birthDate: '1990-05-20',
);

void main() {
  group('ClientRegistration', () {
    test('deve comparar pelo valor', () {
      const same = ClientRegistration(
        name: 'Maria da Silva',
        email: 'maria.silva@exemplo.com',
        password: 'senha-forte-1',
        cpf: '52998224725',
        phone: '44999998888',
        birthDate: '1990-05-20',
      );
      const other = ClientRegistration(
        name: 'Maria da Silva',
        email: 'maria.silva@exemplo.com',
        password: 'outra-senha-1',
        cpf: '52998224725',
        phone: '44999998888',
        birthDate: '1990-05-20',
      );

      expect(_registration, same);
      expect(_registration.hashCode, same.hashCode);
      expect(_registration, isNot(other));
    });

    test('não deve mostrar a senha nem o CPF no toString (RM09)', () {
      final text = _registration.toString();

      expect(text, isNot(contains('senha-forte-1')));
      expect(text, isNot(contains('52998224725')));
      expect(text, contains('Maria da Silva'));
    });
  });

  group('RegistrationField', () {
    test('deve achar o campo pelo nome da API', () {
      expect(RegistrationField.fromApiName('birthDate'), RegistrationField.birthDate);
      expect(RegistrationField.fromApiName('cpf'), RegistrationField.cpf);
    });

    test('deve devolver null para um campo que o app não conhece', () {
      expect(RegistrationField.fromApiName('role'), isNull);
      expect(RegistrationField.fromApiName(null), isNull);
    });
  });
}
