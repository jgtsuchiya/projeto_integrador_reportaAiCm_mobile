import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/data/repositories/api_registration_repository.dart';
import 'package:reportaai_cm/features/auth/domain/models/client_registration.dart';
import 'package:reportaai_cm/features/auth/domain/models/registration_result.dart';

import '../../../../support/fake_http_adapter.dart';
import '../../../../support/fake_profile_repository.dart';

const _registration = ClientRegistration(
  name: 'Maria da Silva',
  email: 'maria.silva@exemplo.com',
  password: 'senha-forte-1',
  cpf: '52998224725',
  phone: '44999998888',
  birthDate: '1990-05-20',
);

/// O corpo de erro da aplicação, como a API responde.
Map<String, Object?> _error(int status, String message, {Object? details}) => {
  'statusCode': status,
  'error': 'Erro',
  'message': message,
  'details': ?details,
};

void main() {
  group('ApiRegistrationRepository', () {
    late FakeHttpAdapter adapter;
    late ApiRegistrationRepository sut;

    setUp(() {
      adapter = FakeHttpAdapter();
      sut = ApiRegistrationRepository(fakeDio(adapter));
    });

    test('deve chamar o POST /api/clients e devolver o RegistrationSuccess no 201', () async {
      adapter.reply(201, body: clientProfileJson);

      final result = await sut.register(_registration);

      expect(result, const RegistrationSuccess());
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/clients');
      expect(request.data, {
        'name': 'Maria da Silva',
        'email': 'maria.silva@exemplo.com',
        'password': 'senha-forte-1',
        'cpf': '52998224725',
        'phone': '44999998888',
        'birthDate': '1990-05-20',
      });
    });

    group('400', () {
      test('deve devolver a mensagem de cada campo do details (RM11)', () async {
        adapter.reply(
          400,
          body: _error(
            400,
            'Dados inválidos.',
            details: [
              {'field': 'cpf', 'message': 'CPF inválido.'},
              {'field': 'password', 'message': 'A senha deve ter de 8 a 128 caracteres.'},
            ],
          ),
        );

        expect(
          await sut.register(_registration),
          const RegistrationFieldErrors({
            RegistrationField.cpf: 'CPF inválido.',
            RegistrationField.password: 'A senha deve ter de 8 a 128 caracteres.',
          }),
        );
      });

      test('deve ficar com a primeira mensagem de cada campo e ignorar os desconhecidos', () async {
        adapter.reply(
          400,
          body: _error(
            400,
            'Dados inválidos.',
            details: [
              {'field': 'phone', 'message': 'Telefone inválido. Informe o DDD e o número.'},
              {'field': 'phone', 'message': 'Outra mensagem.'},
              {'field': 'role', 'message': 'Campo desconhecido.'},
            ],
          ),
        );

        expect(
          await sut.register(_registration),
          const RegistrationFieldErrors({
            RegistrationField.phone: 'Telefone inválido. Informe o DDD e o número.',
          }),
        );
      });

      test('deve lançar a ValidationException sem um campo que o app conheça', () async {
        adapter.reply(400, body: _error(400, 'Dados inválidos.'));

        await expectLater(
          sut.register(_registration),
          throwsA(
            isA<ValidationException>().having((e) => e.message, 'message', 'Dados inválidos.'),
          ),
        );
      });
    });

    group('409', () {
      for (final (field, message, expected) in [
        ('email', 'E-mail já cadastrado.', RegistrationField.email),
        ('cpf', 'CPF já cadastrado.', RegistrationField.cpf),
      ]) {
        test('deve devolver o campo $field que já tem conta, com a mensagem da API', () async {
          adapter.reply(409, body: _error(409, message, details: {'field': field}));

          expect(
            await sut.register(_registration),
            RegistrationFieldErrors({expected: message}, alreadyInUse: expected),
          );
        });
      }

      test('deve lançar a ConflictException sem um campo que o app conheça', () async {
        adapter.reply(409, body: _error(409, 'Esses dados já estão cadastrados.'));

        await expectLater(sut.register(_registration), throwsA(isA<ConflictException>()));
      });
    });

    test('deve devolver o RegistrationRateLimited com o Retry-After do 429', () async {
      adapter.reply(429, body: _error(429, 'Muitas requisições.'), headers: {'retry-after': '42'});

      expect(
        await sut.register(_registration),
        const RegistrationRateLimited(retryAfter: Duration(seconds: 42)),
      );
    });

    test('deve esperar a janela inteira do limite no 429 sem o Retry-After', () async {
      adapter.reply(429, body: _error(429, 'Muitas requisições.'));

      expect(
        await sut.register(_registration),
        const RegistrationRateLimited(retryAfter: RegistrationRateLimited.defaultRetryAfter),
      );
    });

    test('deve lançar a NetworkException sem conexão', () async {
      adapter.failWith(DioExceptionType.connectionError);

      await expectLater(sut.register(_registration), throwsA(isA<NetworkException>()));
    });

    test('deve lançar a ServerException no 5xx', () async {
      adapter.reply(500, body: _error(500, 'Erro interno.'));

      await expectLater(sut.register(_registration), throwsA(isA<ServerException>()));
    });
  });
}
