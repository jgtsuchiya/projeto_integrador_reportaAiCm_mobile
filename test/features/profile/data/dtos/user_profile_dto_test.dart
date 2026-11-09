import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/utils/date_formatters.dart';
import 'package:reportaai_cm/features/profile/data/dtos/user_profile_dto.dart';
import 'package:reportaai_cm/features/profile/domain/models/role.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_profile.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_status.dart';

import '../../../../support/fake_profile_repository.dart';

void main() {
  group('UserProfileDto', () {
    UserProfile profileOf(Map<String, Object?> json) => UserProfileDto.fromJson(json).toModel();

    /// O [clientProfileJson] com os [changes]. Um valor `_absent` remove o campo.
    Map<String, Object?> clientJsonWith(Map<String, Object?> changes) => {
      for (final MapEntry(:key, :value) in {...clientProfileJson, ...changes}.entries)
        if (value != _absent) key: value,
    };

    test('deve ler o JSON do Client do FRONTEND.md do backend', () {
      expect(profileOf(clientProfileJson), clientProfile);
    });

    test('deve ler o JSON do ADM, sem os campos do Client', () {
      final sut = profileOf({
        'id': '7d0c2a8e-5b1f-4f0e-9a51-1c3f2b6d8e90',
        'role': 'ADMIN',
        'name': 'Ana Souza',
        'email': 'ana.souza@exemplo.com',
        'status': 'ACTIVE',
        'emailVerifiedAt': '2026-09-01T12:00:00.000Z',
        'mfaEnabled': false,
        'lastLoginAt': null,
        'createdAt': '2026-09-01T12:00:00.000Z',
        'updatedAt': '2026-09-01T12:00:00.000Z',
      });

      expect(sut, adminProfile);
      expect(sut.cpf, isNull);
      expect(sut.phone, isNull);
      expect(sut.birthDate, isNull);
    });

    test('deve aceitar os campos do Client vindos como null', () {
      final sut = profileOf(clientJsonWith({'cpf': null, 'phone': null, 'birthDate': null}));

      expect((sut.cpf, sut.phone, sut.birthDate), (null, null, null));
    });

    test('deve converter os papéis da API, e o desconhecido em Role.unknown', () {
      for (final (code, role) in [
        ('CLIENT', Role.client),
        ('ADMIN', Role.admin),
        ('SUPER_ADMIN', Role.superAdmin),
        ('AUDITOR', Role.unknown),
        ('client', Role.unknown),
      ]) {
        expect(profileOf(clientJsonWith({'role': code})).role, role, reason: code);
      }
    });

    test('deve converter os status da API, e o desconhecido em UserStatus.unknown', () {
      for (final (code, status) in [
        ('PENDING', UserStatus.pending),
        ('ACTIVE', UserStatus.active),
        ('INACTIVE', UserStatus.inactive),
        ('BLOCKED', UserStatus.unknown),
      ]) {
        expect(profileOf(clientJsonWith({'status': code})).status, status, reason: code);
      }
    });

    test('deve ler as datas com hora em UTC, como vieram', () {
      final sut = profileOf(clientJsonWith({'emailVerifiedAt': '2026-10-05T10:00:00.000Z'}));

      expect(sut.emailVerifiedAt, DateTime.utc(2026, 10, 5, 10));
      expect(sut.emailVerifiedAt!.isUtc, isTrue);
      expect(sut.createdAt.isUtc, isTrue);
    });

    group('birthDate', () {
      test('deve ler a data sem hora, à meia-noite no fuso do aparelho', () {
        final sut = profileOf(clientProfileJson).birthDate!;

        expect(sut, DateTime(1990, 5, 20));
        expect(sut.isUtc, isFalse);
      });

      test('deve mostrar 20/05/1990 sem voltar um dia no fuso do Brasil (UTC-3)', () {
        final sut = profileOf(clientProfileJson).birthDate!;

        // Lida como meia-noite UTC, a data viraria 19/05/1990 21:00 no toLocal() do Brasil.
        expect(formatDate(sut), '20/05/1990');
        expect(formatDate(sut.toLocal()), '20/05/1990');
      });

      test('deve ler as datas que mudam de mês e de ano, e o 29 de fevereiro', () {
        for (final (value, date) in [
          ('2000-01-01', DateTime(2000)),
          ('1999-12-31', DateTime(1999, 12, 31)),
          ('2004-02-29', DateTime(2004, 2, 29)),
        ]) {
          expect(profileOf(clientJsonWith({'birthDate': value})).birthDate, date, reason: value);
        }
      });

      test('deve recusar a data fora do formato ou que não existe', () {
        for (final value in [
          '20/05/1990',
          '1990-5-20',
          '1990-05-20T00:00:00.000Z',
          '2001-02-29',
          '1990-13-01',
          '1990-04-31',
          '',
        ]) {
          expect(
            () => UserProfileDto.fromJson(clientJsonWith({'birthDate': value})),
            throwsFormatException,
            reason: value,
          );
        }
      });
    });

    test('deve recusar o JSON fora do formato', () {
      for (final json in <Object?>[
        null,
        'CLIENT',
        <Object?>[clientProfileJson],
        clientJsonWith({'id': _absent}),
        clientJsonWith({'role': null}),
        clientJsonWith({'email': 42}),
        clientJsonWith({'mfaEnabled': 'false'}),
        clientJsonWith({'createdAt': _absent}),
        clientJsonWith({'updatedAt': 'ontem'}),
        clientJsonWith({'emailVerifiedAt': 0}),
        clientJsonWith({'lastLoginAt': 'ontem'}),
        clientJsonWith({'phone': 44999998888}),
      ]) {
        expect(() => UserProfileDto.fromJson(json), throwsFormatException, reason: '$json');
      }
    });

    test('não deve mostrar o CPF na mensagem do erro de formato (RM09)', () {
      expect(
        () => UserProfileDto.fromJson(clientJsonWith({'cpf': 52998224725})),
        throwsA(
          isA<FormatException>()
              .having((e) => e.message, 'message', contains('"cpf"'))
              .having((e) => e.toString(), 'toString', isNot(contains('52998224725'))),
        ),
      );
    });
  });
}

/// Marca, no `clientJsonWith`, o campo que sai do JSON.
const _absent = Object();
