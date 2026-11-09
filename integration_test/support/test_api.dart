import 'dart:math';

import 'package:dio/dio.dart';
import 'package:reportaai_cm/core/config/app_config.dart';

/// Um Client criado pelo [TestApi.registerClient], com os dados do cadastro. A senha segue a
/// política da RN08, como a das contas dos testes e2e do backend.
final class TestClient {
  const new({
    required this.email,
    required this.cpf,
    this.name = 'Maria da Silva',
    this.password = 'senha-forte-1',
    this.phone = '(44) 99999-8888',
    this.birthDate = '1990-05-20',
  });

  final String email;

  /// Só os dígitos, como a API devolve.
  final String cpf;

  final String name;
  final String password;
  final String phone;

  /// No formato da API, `AAAA-MM-DD`.
  final String birthDate;
}

/// A API local para os testes de integração, chamada por fora do app: sem o SDK do SuperTokens e
/// sem a sessão do aparelho. Prepara o cenário de cada teste, como o `E2eApp` do backend, pelos
/// mesmos caminhos do app: o Client é criado pelo autocadastro e sai pela autoexclusão.
///
/// Os erros dizem o status e a mensagem da API, sem o corpo inteiro: a resposta do cadastro traz
/// o CPF (RM09).
final class TestApi {
  new(AppConfig config)
    : _dio = Dio(
        BaseOptions(
          baseUrl: config.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          // O teste confere o status de cada resposta, para dizer o que falhou.
          validateStatus: (_) => true,
        ),
      );

  final Dio _dio;

  /// Cadastra um Client novo pelo `POST /api/clients`, com um e-mail e um CPF que não se repetem
  /// entre as execuções: o e-mail e o CPF são únicos na API, e as falhas de login de um e-mail
  /// fixo se somariam até o bloqueio (RN17).
  Future<TestClient> registerClient() async {
    final client = TestClient(
      email: 'maria.app.${_uniqueId()}@reportaai.invalid',
      cpf: randomCpf(),
    );

    final response = await _dio.post<Object?>(
      '/clients',
      data: {
        'name': client.name,
        'email': client.email,
        'password': client.password,
        'cpf': client.cpf,
        'phone': client.phone,
        'birthDate': client.birthDate,
      },
    );
    _expectStatus(response, 201, 'O cadastro do Client de teste');

    return client;
  }

  /// Exclui a conta do [client] pelo `DELETE /api/users/me`, com uma sessão aberta só para isso,
  /// para a base de dev não acumular as contas dos testes. A exclusão encerra todas as sessões da
  /// conta, inclusive a que um teste interrompido no meio deixou no aparelho.
  Future<void> deleteClient(TestClient client) async {
    final signIn = await _dio.post<Object?>(
      '/auth/signin',
      data: {
        'formFields': [
          {'id': 'email', 'value': client.email},
          {'id': 'password', 'value': client.password},
        ],
      },
      // O modo header, como o app: os tokens voltam nos headers da resposta.
      options: Options(headers: {'rid': 'emailpassword', 'st-auth-mode': 'header'}),
    );
    final accessToken = signIn.headers.value('st-access-token');
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('O login para excluir o Client de teste falhou: ${_describe(signIn)}');
    }

    final response = await _dio.delete<Object?>(
      '/users/me',
      data: {'password': client.password},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    _expectStatus(response, 204, 'A exclusão do Client de teste');
  }
}

/// Um CPF com os dígitos verificadores válidos, para cada Client ter o seu, como o `randomCpf`
/// dos testes e2e do backend.
String randomCpf() {
  final random = Random();
  final digits = [for (var i = 0; i < 9; i++) random.nextInt(10)];

  for (final length in [9, 10]) {
    var sum = 0;
    for (var index = 0; index < length; index++) {
      sum += digits[index] * (length + 1 - index);
    }
    digits.add(sum * 10 % 11 % 10);
  }

  return digits.join();
}

/// 16 caracteres hexadecimais aleatórios, no papel do `randomUUID` do backend.
String _uniqueId() {
  final random = Random.secure();
  return [for (var i = 0; i < 8; i++) random.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
}

void _expectStatus(Response<Object?> response, int expected, String action) {
  if (response.statusCode == expected) return;

  throw StateError(
    '$action deveria responder $expected e respondeu ${_describe(response)}\n'
    'Confira se a API local está na develop do backend, com as migrations e o seed rodados '
    '(npm run migration:run e npm run seed): o 500 no cadastro costuma ser um dos dois.',
  );
}

/// O status e a mensagem da API (ou o `status` do SuperTokens), sem o resto do corpo.
String _describe(Response<Object?> response) {
  final body = response.data;
  final message = body is Map ? body['message'] ?? body['status'] : null;

  return [response.statusCode, ?message].join(' ');
}
