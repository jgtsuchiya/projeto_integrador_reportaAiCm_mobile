import 'dart:convert';
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

/// Uma sessão aberta pelo [TestApi.signIn], por fora do app, como a do `api.http` ou a de outro
/// aparelho.
final class TestSession {
  const new({
    required this.accessToken,
    required this.refreshToken,
    required this.isSecondFactorPending,
  });

  final String accessToken;
  final String refreshToken;

  /// Se a sessão está pendente da segunda etapa: a conta tem a verificação em duas etapas ativa.
  final bool isSecondFactorPending;
}

/// A API local para os testes de integração, chamada por fora do app: sem o SDK do SuperTokens e
/// sem a sessão do aparelho. Prepara o cenário de cada teste, como o `E2eApp` do backend, pelos
/// mesmos caminhos do app: o Client é criado pelo autocadastro e sai pela autoexclusão.
///
/// Lê também os e-mails da API no Mailpit do `docker-compose.yml` do backend, na mesma máquina da
/// API, na porta 8025 ([mailpitUrl]), como o `mail.integration-spec.ts` do backend.
///
/// Os erros dizem o status e a mensagem da API, sem o corpo inteiro: a resposta do cadastro traz
/// o CPF (RM09).
final class TestApi {
  new(AppConfig config)
    : mailpitUrl = Uri.parse(config.apiUrl).replace(port: 8025, path: '/api/v1').toString(),
      _dio = Dio(
        BaseOptions(
          baseUrl: config.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          // O teste confere o status de cada resposta, para dizer o que falhou.
          validateStatus: (_) => true,
        ),
      );

  /// A API do Mailpit, no endereço da API com a porta 8025: `http://10.0.2.2:8025/api/v1` no
  /// emulador. No celular pelo USB, o `adb reverse tcp:8025 tcp:8025` também é preciso.
  final String mailpitUrl;

  final Dio _dio;

  /// Os dados de um Client novo, sem cadastrar, para o teste cadastrar pela tela do app. O e-mail
  /// e o CPF não se repetem entre as execuções: os dois são únicos na API, e as falhas de login de
  /// um e-mail fixo se somariam até o bloqueio (RN17).
  TestClient newClient() =>
      TestClient(email: 'maria.app.${_uniqueId()}@reportaai.invalid', cpf: randomCpf());

  /// Cadastra um Client pelo `POST /api/clients`: um novo ([newClient]), ou o [client] passado,
  /// como o cadastro de novo com o e-mail e o CPF de uma conta excluída.
  Future<TestClient> registerClient([TestClient? client]) async {
    client ??= newClient();

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

  /// Abre uma sessão para o [client] pelo `POST /api/auth/signin`, no modo header, como o app,
  /// com a [password] (a do cadastro, se não for passada). Devolve `null` quando o login é recusado
  /// (`WRONG_CREDENTIALS_ERROR`), como o da conta excluída.
  Future<TestSession?> signIn(TestClient client, {String? password}) async {
    final response = await _dio.post<Object?>(
      '/auth/signin',
      data: {
        'formFields': [
          {'id': 'email', 'value': client.email},
          {'id': 'password', 'value': password ?? client.password},
        ],
      },
      // O modo header, como o app: os tokens voltam nos headers da resposta.
      options: Options(headers: {'rid': 'emailpassword', 'st-auth-mode': 'header'}),
    );
    if (response.data case {'status': 'WRONG_CREDENTIALS_ERROR'}) return null;

    final accessToken = response.headers.value('st-access-token');
    final refreshToken = response.headers.value('st-refresh-token');
    if (accessToken == null || accessToken.isEmpty || refreshToken == null) {
      throw StateError('O login do Client de teste falhou: ${_describe(response)}');
    }

    return TestSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      isSecondFactorPending: _isSecondFactorPending(response.headers.value('front-token')),
    );
  }

  /// O status da renovação da sessão do [refreshToken] (`POST /api/auth/session/refresh`): 200
  /// enquanto a sessão vale, 401 depois de encerrada (pela lista de sessões, pela troca de senha
  /// ou pela ativação da verificação em duas etapas em outro aparelho).
  Future<int?> refreshStatus(String refreshToken) async {
    final response = await _dio.post<Object?>(
      '/auth/session/refresh',
      options: Options(
        headers: {'st-auth-mode': 'header', 'Authorization': 'Bearer $refreshToken'},
      ),
    );
    return response.statusCode;
  }

  /// Confirma o e-mail do [client] pelo link que a API mandou no cadastro, como o Client faz no
  /// navegador. A ativação da verificação em duas etapas exige o e-mail confirmado.
  Future<void> confirmClientEmail(TestClient client) async {
    await confirmEmail(await emailVerificationToken(client.email));
  }

  /// Exclui a conta do [client] pelo `DELETE /api/users/me`, com uma sessão aberta só para isso,
  /// para a base de dev não acumular as contas dos testes. A exclusão encerra todas as sessões da
  /// conta, inclusive a que um teste interrompido no meio deixou no aparelho.
  ///
  /// A [password] é a atual (a do cadastro, se não for passada), e a [fallbackPassword] vale
  /// quando a atual é recusada, como num teste que falhou no meio da troca de senha. Com a
  /// verificação em duas etapas ativa, o código vem do Mailpit.
  ///
  /// Com [ifExists], a conta que não existe (o teste falhou antes de o app cadastrá-la, ou ela já
  /// foi excluída pela tela) é ignorada: o login dela responde `WRONG_CREDENTIALS_ERROR`.
  Future<void> deleteClient(
    TestClient client, {
    bool ifExists = false,
    String? password,
    String? fallbackPassword,
  }) async {
    var currentPassword = password ?? client.password;
    final startedAt = DateTime.now();
    var session = await signIn(client, password: currentPassword);
    if (session == null && fallbackPassword != null) {
      currentPassword = fallbackPassword;
      session = await signIn(client, password: currentPassword);
    }
    if (session == null) {
      if (ifExists) return;
      throw StateError('O login para excluir o Client de teste foi recusado.');
    }

    var accessToken = session.accessToken;
    if (session.isSecondFactorPending) {
      accessToken = await _completeSecondFactor(client.email, accessToken, after: startedAt);
    }

    final response = await _dio.delete<Object?>(
      '/users/me',
      data: {'password': currentPassword},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    _expectStatus(response, 204, 'A exclusão do Client de teste');
  }

  /// O código de 6 dígitos do e-mail da segunda etapa que a API mandou para o [email] depois de
  /// [after], lido no Mailpit. Espera o e-mail chegar por até [timeout].
  Future<String> loginCode(
    String email, {
    required DateTime after,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final text = await _waitForMail(
      email,
      subject: _loginCodeSubject,
      after: after,
      timeout: timeout,
      description: 'e-mail do código da segunda etapa',
    );
    if (_loginCodeLine.firstMatch(text)?.group(1) case final code?) return code;

    throw StateError('O e-mail do código de $email não tem o código de 6 dígitos.');
  }

  /// Conclui a segunda etapa da sessão pendente do [accessToken] e devolve o access token da
  /// sessão completa. Um login menos de 1 minuto depois do anterior não manda outro código: se o
  /// do último e-mail já foi usado, pede outro depois da espera.
  Future<String> _completeSecondFactor(
    String email,
    String accessToken, {
    required DateTime after,
  }) async {
    final auth = Options(headers: {'Authorization': 'Bearer $accessToken'});

    // Sem e-mail novo, vale o do login anterior, se o código dele ainda não foi usado.
    final text =
        await _findMail(
          email,
          subject: _loginCodeSubject,
          after: after,
          timeout: const Duration(seconds: 5),
        ) ??
        await _waitForMail(
          email,
          subject: _loginCodeSubject,
          timeout: Duration.zero,
          description: 'e-mail do código da segunda etapa',
        );
    var code = _loginCodeLine.firstMatch(text)?.group(1);

    var verify = await _dio.post<Object?>('/mfa/verify', data: {'code': code}, options: auth);
    if (verify.statusCode == 422) {
      final deadline = DateTime.now().add(const Duration(seconds: 75));
      final resentAt = DateTime.now();
      while ((await _dio.post<Object?>('/mfa/code', options: auth)).statusCode != 204) {
        if (DateTime.now().isAfter(deadline)) {
          throw StateError('A API não mandou outro código da segunda etapa para $email.');
        }
        await Future<void>.delayed(const Duration(seconds: 5));
      }
      code = await loginCode(email, after: resentAt);
      verify = await _dio.post<Object?>('/mfa/verify', data: {'code': code}, options: auth);
    }
    _expectStatus(verify, 204, 'A segunda etapa do login do Client de teste');

    return verify.headers.value('st-access-token') ?? accessToken;
  }

  /// O token do link de confirmação do último e-mail que a API mandou para o [email], lido no
  /// Mailpit. Espera o e-mail chegar por até [timeout]: o cadastro responde antes de o SMTP
  /// entregar a mensagem.
  Future<String> emailVerificationToken(
    String email, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final text = await _waitForMail(
      email,
      subject: 'Confirme o seu e-mail',
      timeout: timeout,
      description: 'e-mail de confirmação',
    );
    if (_verificationToken.firstMatch(text)?.group(1) case final token?) return token;

    throw StateError('O e-mail de confirmação de $email não tem o link com o token.');
  }

  /// O texto do e-mail mais novo para o [email] com o [subject], enviado depois de [after] (se
  /// passado), lido no Mailpit. Espera o e-mail chegar por até [timeout].
  Future<String> _waitForMail(
    String email, {
    required String subject,
    required Duration timeout,
    required String description,
    DateTime? after,
  }) async {
    final text = await _findMail(email, subject: subject, timeout: timeout, after: after);
    if (text != null) return text;

    throw StateError(
      'O $description de $email não chegou ao Mailpit ($mailpitUrl) em ${timeout.inSeconds} s. '
      'Confira se o Mailpit do backend está no ar.',
    );
  }

  /// Como o [_waitForMail], mas devolve `null` quando o e-mail não chega a tempo.
  Future<String?> _findMail(
    String email, {
    required String subject,
    required Duration timeout,
    DateTime? after,
  }) async {
    final deadline = DateTime.now().add(timeout);
    // O relógio do Mailpit e o do aparelho podem diferir um pouco, na mesma máquina.
    final since = after?.subtract(const Duration(seconds: 2));

    while (true) {
      final search = await _dio.get<Object?>(
        '$mailpitUrl/search',
        queryParameters: {'query': 'to:"$email" subject:"$subject"'},
      );
      _expectStatus(search, 200, 'A busca do e-mail "$subject" no Mailpit');

      // O Mailpit devolve as mensagens da mais nova para a mais antiga.
      final id = switch (search.data) {
        {'messages': [{'ID': final String id, 'Created': final String created}, ...]}
            when since == null || DateTime.parse(created).isAfter(since) =>
          id,
        _ => null,
      };
      if (id != null) {
        final message = await _dio.get<Object?>('$mailpitUrl/message/$id');
        _expectStatus(message, 200, 'A leitura do e-mail "$subject" no Mailpit');

        return switch (message.data) {
          {'Text': final String text} => text,
          _ => '',
        };
      }

      if (!DateTime.now().isBefore(deadline)) return null;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  /// Confirma o e-mail pelo `POST /api/email-verifications/confirm`, como a página
  /// `/verificar-email` do painel faz no navegador do celular.
  Future<void> confirmEmail(String token) async {
    final response = await _dio.post<Object?>(
      '/email-verifications/confirm',
      data: {'token': token},
    );
    _expectStatus(response, 204, 'A confirmação do e-mail');
  }
}

/// O token do link `<WEB_APP_URL>/verificar-email?token=<token>`, em base64url.
final _verificationToken = RegExp(r'/verificar-email\?token=([A-Za-z0-9_-]+)');

/// O assunto do e-mail do código, o `LOGIN_CODE_MAIL_SUBJECT` do backend.
const _loginCodeSubject = 'Seu código de acesso ao ReportaAi Cm';

/// O código, sozinho numa linha do texto do e-mail.
final _loginCodeLine = RegExp(r'^(\d{6})$', multiLine: true);

/// Se o front token do login marca a sessão como pendente da segunda etapa: a claim
/// `mfa-verified` com `v` igual a `false`, como o app lê.
bool _isSecondFactorPending(String? frontToken) {
  if (frontToken == null || frontToken.isEmpty || frontToken == 'remove') return false;

  final json = jsonDecode(utf8.decode(base64.decode(base64.normalize(frontToken))));
  return switch (json) {
    {'up': {'mfa-verified': {'v': false}}} => true,
    _ => false,
  };
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
