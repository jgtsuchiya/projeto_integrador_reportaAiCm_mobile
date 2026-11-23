import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/auth/domain/models/registration_validation.dart';
import 'package:reportaai_cm/features/profile/domain/models/profile_changes.dart';

import '../../../../support/fake_profile_repository.dart';

final _now = DateTime.utc(2026, 11, 22, 12);

void main() {
  group('ProfileField', () {
    test('deve achar o campo pelo nome da API', () {
      expect(ProfileField.fromApiName('name'), ProfileField.name);
      expect(ProfileField.fromApiName('phone'), ProfileField.phone);
      expect(ProfileField.fromApiName('birthDate'), ProfileField.birthDate);
      expect(ProfileField.fromApiName('cpf'), isNull);
      expect(ProfileField.fromApiName(null), isNull);
    });
  });

  group('ProfileChanges', () {
    test('deve estar vazio sem nenhum campo', () {
      expect(const ProfileChanges().isEmpty, isTrue);
      expect(const ProfileChanges(name: 'Maria').isEmpty, isFalse);
      expect(const ProfileChanges(phone: '44999998888').isEmpty, isFalse);
      expect(const ProfileChanges(birthDate: '1990-05-20').isEmpty, isFalse);
    });

    test('deve comparar pelo valor', () {
      expect(const ProfileChanges(name: 'Maria'), const ProfileChanges(name: 'Maria'));
      expect(const ProfileChanges(name: 'Maria'), isNot(const ProfileChanges(phone: 'Maria')));
      expect(
        const ProfileChanges(name: 'Maria').hashCode,
        const ProfileChanges(name: 'Maria').hashCode,
      );
      expect(
        const ProfileChanges(phone: '44999998888').toString(),
        'ProfileChanges(name: null, phone: 44999998888, birthDate: null)',
      );
    });
  });

  group('profileChangesOf', () {
    ProfileChanges changesOf({
      String name = 'Maria da Silva',
      String phone = '44999998888',
      String birthDate = '1990-05-20',
    }) => profileChangesOf(clientProfile, name: name, phone: phone, birthDate: birthDate);

    test('não deve ter mudança com os dados do perfil', () {
      expect(changesOf().isEmpty, isTrue);
    });

    test('não deve contar como mudança os espaços nas pontas do nome', () {
      expect(changesOf(name: '  Maria da Silva ').isEmpty, isTrue);
    });

    test('deve trazer só os campos que mudaram', () {
      expect(changesOf(name: 'Maria Souza'), const ProfileChanges(name: 'Maria Souza'));
      expect(changesOf(phone: '4433334444'), const ProfileChanges(phone: '4433334444'));
      expect(changesOf(birthDate: '1991-06-21'), const ProfileChanges(birthDate: '1991-06-21'));
    });

    test('deve contar o campo apagado como mudança, para a conferência recusar', () {
      expect(
        changesOf(name: '', phone: '', birthDate: ''),
        const ProfileChanges(name: '', phone: '', birthDate: ''),
      );
    });

    test('deve tratar o perfil sem os campos do Client como campos vazios', () {
      final changes = profileChangesOf(
        adminProfile,
        name: adminProfile.name,
        phone: '',
        birthDate: '',
      );

      expect(changes.isEmpty, isTrue);
    });
  });

  group('validateProfileChanges', () {
    Map<ProfileField, String> validate(ProfileChanges changes) =>
        validateProfileChanges(changes, now: _now);

    test('deve aceitar os dados válidos e o que não mudou', () {
      expect(validate(const ProfileChanges()), isEmpty);
      expect(
        validate(
          const ProfileChanges(
            name: 'Maria Souza',
            phone: '(44) 3333-4444',
            birthDate: '2008-11-21',
          ),
        ),
        isEmpty,
      );
    });

    test('deve pedir o nome vazio e recusar o nome longo', () {
      expect(validate(const ProfileChanges(name: '   ')), {
        ProfileField.name: RegistrationMessages.nameMissing,
      });
      expect(validate(ProfileChanges(name: 'a' * 121)), {
        ProfileField.name: RegistrationMessages.nameTooLong,
      });
    });

    test('deve pedir o telefone vazio e recusar o inválido', () {
      expect(validate(const ProfileChanges(phone: '')), {
        ProfileField.phone: RegistrationMessages.phoneMissing,
      });
      expect(validate(const ProfileChanges(phone: '4499')), {
        ProfileField.phone: RegistrationMessages.phoneInvalid,
      });
    });

    test('deve pedir a data vazia e recusar a inválida e a de hoje', () {
      expect(validate(const ProfileChanges(birthDate: '')), {
        ProfileField.birthDate: RegistrationMessages.birthDateMissing,
      });
      expect(validate(const ProfileChanges(birthDate: '2001-02-29')), {
        ProfileField.birthDate: RegistrationMessages.birthDateInvalid,
      });
      expect(validate(const ProfileChanges(birthDate: '20/05')), {
        ProfileField.birthDate: RegistrationMessages.birthDateInvalid,
      });
      expect(validate(const ProfileChanges(birthDate: '2026-11-22')), {
        ProfileField.birthDate: RegistrationMessages.birthDateNotInPast,
      });
    });
  });
}
