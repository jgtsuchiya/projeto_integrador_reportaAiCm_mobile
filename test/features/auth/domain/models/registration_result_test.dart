import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/auth/domain/models/client_registration.dart';
import 'package:reportaai_cm/features/auth/domain/models/registration_result.dart';

void main() {
  group('RegistrationResult', () {
    test('deve comparar cada resultado pelo valor', () {
      expect(const RegistrationSuccess(), const RegistrationSuccess());
      expect(const RegistrationSuccess().hashCode, const RegistrationSuccess().hashCode);
      expect(
        const RegistrationRateLimited(retryAfter: Duration(seconds: 3)),
        const RegistrationRateLimited(retryAfter: Duration(seconds: 3)),
      );
      expect(
        const RegistrationRateLimited(retryAfter: Duration(seconds: 3)).hashCode,
        const RegistrationRateLimited(retryAfter: Duration(seconds: 3)).hashCode,
      );
    });

    test('deve comparar os erros dos campos sem depender da ordem', () {
      const first = RegistrationFieldErrors({
        RegistrationField.cpf: 'CPF inválido.',
        RegistrationField.phone: 'Telefone inválido.',
      });
      const second = RegistrationFieldErrors({
        RegistrationField.phone: 'Telefone inválido.',
        RegistrationField.cpf: 'CPF inválido.',
      });

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(
        first,
        isNot(
          const RegistrationFieldErrors({
            RegistrationField.cpf: 'CPF inválido.',
            RegistrationField.phone: 'Telefone inválido.',
          }, alreadyInUse: RegistrationField.cpf),
        ),
      );
    });

    test('deve devolver a mensagem de cada campo', () {
      const sut = RegistrationFieldErrors({
        RegistrationField.email: 'E-mail já cadastrado.',
      }, alreadyInUse: RegistrationField.email);

      expect(sut.messageFor(RegistrationField.email), 'E-mail já cadastrado.');
      expect(sut.messageFor(RegistrationField.cpf), isNull);
      expect(sut.toString(), contains('alreadyInUse: email'));
    });

    test('deve descrever cada resultado no toString', () {
      expect(const RegistrationSuccess().toString(), 'RegistrationSuccess()');
      expect(
        const RegistrationRateLimited(retryAfter: Duration(seconds: 3)).toString(),
        contains('0:00:03'),
      );
    });
  });
}
