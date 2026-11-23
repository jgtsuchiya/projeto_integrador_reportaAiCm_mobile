import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/profile/data/repositories/api_profile_repository.dart';
import 'package:reportaai_cm/features/profile/domain/models/profile_changes.dart';

import '../../../../support/fake_http_adapter.dart';
import '../../../../support/fake_profile_repository.dart';

void main() {
  group('ApiProfileRepository', () {
    late FakeHttpAdapter adapter;
    late ApiProfileRepository sut;

    setUp(() {
      adapter = FakeHttpAdapter();
      sut = ApiProfileRepository(fakeDio(adapter));
    });

    test('deve chamar o GET /api/users/me e devolver o modelo', () async {
      adapter.reply(200, body: clientProfileJson);

      final result = await sut.getMe();

      expect(result, clientProfile);
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.uri.path, '/api/users/me');
    });

    test('deve lançar a UnauthorizedException quando a sessão acabou', () async {
      adapter.reply(401, body: {'message': 'unauthorised'});

      await expectLater(sut.getMe(), throwsA(isA<UnauthorizedException>()));
    });

    test('deve lançar a SecondFactorPendingException com a sessão pendente', () async {
      adapter.reply(
        403,
        body: {
          'message': 'invalid claim',
          'claimValidationErrors': [
            {'id': 'mfa-verified'},
          ],
        },
      );

      await expectLater(sut.getMe(), throwsA(isA<SecondFactorPendingException>()));
    });

    test('deve lançar a NetworkException com a API desligada', () async {
      adapter.failWith(DioExceptionType.connectionError);

      await expectLater(sut.getMe(), throwsA(isA<NetworkException>()));
    });

    test('deve lançar a ServerException com a resposta fora do formato', () async {
      adapter.reply(200, body: {'id': 'user-1', 'role': 'CLIENT'});

      await expectLater(sut.getMe(), throwsA(isA<ServerException>()));
    });

    group('resendEmailVerification', () {
      test('deve chamar o POST /api/users/me/email-verification', () async {
        adapter.reply(204);

        await sut.resendEmailVerification();

        expect(adapter.requests.single.method, 'POST');
        expect(adapter.requests.single.uri.path, '/api/users/me/email-verification');
      });

      test('deve lançar a BusinessRuleException com a message da API no 422', () async {
        const message = 'Um e-mail acabou de ser enviado. Aguarde um minuto para pedir outro.';
        adapter.reply(
          422,
          body: {'statusCode': 422, 'error': 'Unprocessable Entity', 'message': message},
        );

        await expectLater(
          sut.resendEmailVerification(),
          throwsA(
            isA<BusinessRuleException>().having((error) => error.message, 'message', message),
          ),
        );
      });

      test('deve lançar a NetworkException sem conexão', () async {
        adapter.failWith(DioExceptionType.connectionError);

        await expectLater(sut.resendEmailVerification(), throwsA(isA<NetworkException>()));
      });
    });

    group('updateMe', () {
      test('deve chamar o PATCH /api/users/me só com os campos que mudaram', () async {
        adapter.reply(200, body: {...clientProfileJson, 'name': 'Maria Souza'});

        final result = await sut.updateMe(const ProfileChanges(name: '  Maria Souza '));

        final request = adapter.requests.single;
        expect(request.method, 'PATCH');
        expect(request.uri.path, '/api/users/me');
        expect(request.data, {'name': 'Maria Souza'});
        expect(result, clientProfileWith(name: 'Maria Souza'));
      });

      test('deve enviar o telefone e a data de nascimento no formato da API', () async {
        adapter.reply(200, body: clientProfileJson);

        await sut.updateMe(const ProfileChanges(phone: '43988887777', birthDate: '1991-06-21'));

        expect(adapter.requests.single.data, {'phone': '43988887777', 'birthDate': '1991-06-21'});
      });

      test('deve lançar a ValidationException com o erro de cada campo', () async {
        adapter.reply(
          400,
          body: {
            'statusCode': 400,
            'error': 'Bad Request',
            'message': 'Dados inválidos.',
            'details': [
              {'field': 'phone', 'message': 'Telefone inválido. Informe o DDD e o número.'},
            ],
          },
        );

        await expectLater(
          sut.updateMe(const ProfileChanges(phone: '4499')),
          throwsA(
            isA<ValidationException>().having(
              (error) => error.messageFor('phone'),
              'messageFor(phone)',
              'Telefone inválido. Informe o DDD e o número.',
            ),
          ),
        );
      });

      test('deve lançar a ServerException com o perfil fora do formato', () async {
        adapter.reply(200, body: {'id': 'user-1'});

        await expectLater(
          sut.updateMe(const ProfileChanges(name: 'Maria')),
          throwsA(isA<ServerException>()),
        );
      });
    });

    group('changePassword', () {
      test('deve chamar o PATCH /api/users/me/password com as duas senhas', () async {
        adapter.reply(204);

        await sut.changePassword(currentPassword: 'senha-atual-1', newPassword: 'senha-nova-1');

        final request = adapter.requests.single;
        expect(request.method, 'PATCH');
        expect(request.uri.path, '/api/users/me/password');
        expect(request.data, {'currentPassword': 'senha-atual-1', 'newPassword': 'senha-nova-1'});
      });

      test('deve lançar a BusinessRuleException da senha atual incorreta, com o campo', () async {
        adapter.reply(422, body: _incorrectPassword('currentPassword'));

        await expectLater(
          sut.changePassword(currentPassword: 'errada-1', newPassword: 'senha-nova-1'),
          throwsA(
            isA<BusinessRuleException>().having((error) => error.field, 'field', 'currentPassword'),
          ),
        );
      });
    });

    group('setMfa', () {
      test('deve chamar o PATCH /api/users/me/mfa e devolver o perfil', () async {
        adapter.reply(200, body: {...clientProfileJson, 'mfaEnabled': true});

        final result = await sut.setMfa(enabled: true, password: 'senha-forte-1');

        final request = adapter.requests.single;
        expect(request.method, 'PATCH');
        expect(request.uri.path, '/api/users/me/mfa');
        expect(request.data, {'enabled': true, 'password': 'senha-forte-1'});
        expect(result.mfaEnabled, isTrue);
      });

      test('deve lançar a BusinessRuleException da senha incorreta, com o campo', () async {
        adapter.reply(422, body: _incorrectPassword('password'));

        await expectLater(
          sut.setMfa(enabled: false, password: 'errada-1'),
          throwsA(isA<BusinessRuleException>().having((error) => error.field, 'field', 'password')),
        );
      });
    });

    group('deleteAccount', () {
      test('deve chamar o DELETE /api/users/me com a senha', () async {
        adapter.reply(204);

        await sut.deleteAccount(password: 'senha-forte-1');

        final request = adapter.requests.single;
        expect(request.method, 'DELETE');
        expect(request.uri.path, '/api/users/me');
        expect(request.data, {'password': 'senha-forte-1'});
      });

      test('deve lançar a BusinessRuleException da senha incorreta, com o campo', () async {
        adapter.reply(422, body: _incorrectPassword('password'));

        await expectLater(
          sut.deleteAccount(password: 'errada-1'),
          throwsA(isA<BusinessRuleException>().having((error) => error.field, 'field', 'password')),
        );
      });

      test('deve lançar a NetworkException sem conexão', () async {
        adapter.failWith(DioExceptionType.connectionError);

        await expectLater(
          sut.deleteAccount(password: 'senha-forte-1'),
          throwsA(isA<NetworkException>()),
        );
      });
    });
  });
}

/// O 422 da senha de confirmação incorreta, depois da T8 do backend.
Map<String, Object?> _incorrectPassword(String field) => {
  'statusCode': 422,
  'error': 'Unprocessable Entity',
  'message': 'Senha incorreta.',
  'details': {'field': field},
};
