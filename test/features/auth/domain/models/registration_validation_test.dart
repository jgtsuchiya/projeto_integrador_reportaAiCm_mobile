import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/auth/domain/models/client_registration.dart';
import 'package:reportaai_cm/features/auth/domain/models/registration_validation.dart';

void main() {
  group('validateRegistration', () {
    final now = DateTime.utc(2026, 9, 27, 12);

    /// Os campos como estão na tela, com a máscara, e a data já em `AAAA-MM-DD`.
    Map<RegistrationField, String> validate({
      String name = 'Maria da Silva',
      String email = 'maria.silva@exemplo.com',
      String password = 'senha-forte-1',
      String cpf = '529.982.247-25',
      String phone = '(44) 99999-8888',
      String birthDate = '1990-05-20',
    }) => validateRegistration(
      name: name,
      email: email,
      password: password,
      cpf: cpf,
      phone: phone,
      birthDate: birthDate,
      now: now,
    );

    test('deve aceitar o cadastro com todos os campos válidos (RM11)', () {
      expect(validate(), isEmpty);
    });

    test('deve aceitar o CPF e o telefone só com os dígitos', () {
      expect(validate(cpf: '52998224725', phone: '4433334444'), isEmpty);
    });

    test('deve pedir cada campo vazio (RM11)', () {
      expect(validate(name: ' ', email: '', password: '', cpf: '', phone: ' ', birthDate: ''), {
        RegistrationField.name: 'Informe o nome.',
        RegistrationField.email: 'Informe o e-mail.',
        RegistrationField.password: 'Informe a senha.',
        RegistrationField.cpf: 'Informe o CPF.',
        RegistrationField.phone: 'Informe o telefone.',
        RegistrationField.birthDate: 'Informe a data de nascimento.',
      });
    });

    // Os mesmos campos inválidos e as mesmas mensagens do register-client.dto.spec.ts do backend,
    // menos o formato da data, que é o da tela.
    test('deve recusar cada campo inválido com a mensagem da API (RM11)', () {
      expect(
        validate(
          email: 'invalido',
          password: 'curta1',
          cpf: '111.111.111-11',
          phone: '123',
          birthDate: '20/05/1990',
        ),
        {
          RegistrationField.email: 'E-mail inválido.',
          RegistrationField.password: 'A senha deve ter de 8 a 128 caracteres.',
          RegistrationField.cpf: 'CPF inválido.',
          RegistrationField.phone: 'Telefone inválido. Informe o DDD e o número.',
          RegistrationField.birthDate: 'Data de nascimento inválida. Use o formato DD/MM/AAAA.',
        },
      );
    });

    test('deve recusar o nome com mais de 120 caracteres', () {
      expect(validate(name: 'a' * 121), {
        RegistrationField.name: 'O nome deve ter no máximo 120 caracteres.',
      });
    });

    test('deve recusar a senha sem letra ou sem número (RN08)', () {
      expect(validate(password: '12345678'), {
        RegistrationField.password: 'A senha deve ter pelo menos uma letra e um número.',
      });
    });

    test('deve recusar a data que não existe, como 29/02 de um ano não bissexto', () {
      expect(validate(birthDate: '2001-02-29'), {
        RegistrationField.birthDate: RegistrationMessages.birthDateInvalid,
      });
    });

    test('deve recusar a data de nascimento de hoje ou futura', () {
      for (final date in ['2026-09-27', '2030-01-01']) {
        expect(validate(birthDate: date), {
          RegistrationField.birthDate: 'A data de nascimento precisa estar no passado.',
        }, reason: date);
      }
    });

    test('deve recusar a data de nascimento antes de 1900, com a mensagem da API', () {
      expect(validate(birthDate: '1899-12-31'), {
        RegistrationField.birthDate: RegistrationMessages.birthDateNotInPast,
      });
    });
  });
}
