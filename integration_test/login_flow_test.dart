import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/config/app_config.dart';
import 'package:reportaai_cm/main.dart' as app;

import 'support/pump_until.dart';
import 'support/test_api.dart';

final Finder _loginTitle = find.text('Entrar no ReportaAi Cm');
final Finder _emailField = find.widgetWithText(TextFormField, 'E-mail');
final Finder _passwordField = find.widgetWithText(TextFormField, 'Senha');

/// O fluxo do Client contra a API de verdade, como o `client-flow.e2e-spec.ts` do backend: o app
/// inteiro, num emulador ou aparelho, com o SDK do SuperTokens e a API local no ar. Não roda no
/// CI (ver docs/TESTING.md):
///
/// ```bash
/// fvm flutter test integration_test/login_flow_test.dart --dart-define-from-file=env/dev.json
/// ```
///
/// O Client é criado pelo `POST /api/clients` no começo e excluído no fim, mesmo quando o teste
/// falha. O aparelho não pode ter uma sessão guardada.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('deve entrar com um Client novo, ver os dados dele na tela inicial e sair', (
    tester,
  ) async {
    final api = TestApi(AppConfig.fromEnvironment());
    final client = await api.registerClient();
    addTearDown(() => api.deleteClient(client));

    await app.main();
    await tester.pumpAndSettle();
    expect(
      _loginTitle,
      findsOneWidget,
      reason: 'O app não abriu no login. Saia da conta no aparelho e rode o teste de novo.',
    );

    // A resposta da API para a senha errada: a mesma da conta que não existe (RM02).
    await _signIn(tester, email: client.email, password: 'senha-errada-1');
    await tester.pumpUntilFound(
      find.text('E-mail ou senha incorretos.'),
      reason: 'O login com a senha errada não mostrou a mensagem.',
    );

    await _signIn(tester, email: client.email, password: client.password);
    await tester.pumpUntilFound(
      find.text('Olá, Maria'),
      reason: 'O login do Client não chegou à tela inicial.',
    );

    // Os dados do GET /api/users/me, formatados, com o CPF mascarado (RM09).
    final cpf = client.cpf;
    for (final value in [
      client.name,
      client.email,
      'E-mail não confirmado',
      '***.${cpf.substring(3, 6)}.${cpf.substring(6, 9)}-**',
      '(44) 99999-8888',
      '20/05/1990',
    ]) {
      expect(find.text(value), findsOneWidget, reason: value);
    }
    expect(find.textContaining('No ReportaAi desde'), findsOneWidget);
    expect(find.textContaining(cpf), findsNothing);

    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Sair')));
    await tester.pumpUntilFound(_loginTitle, reason: 'O "Sair" não voltou ao login.');

    expect(find.text('Sua sessão expirou. Entre de novo.'), findsNothing);
  });
}

/// Preenche o login e toca no "Entrar", como o usuário. Com o teclado aberto, o "Entrar" pode
/// ficar fora da tela: a tela rola até ele antes do toque.
Future<void> _signIn(WidgetTester tester, {required String email, required String password}) async {
  await tester.enterText(_emailField, email);
  await tester.enterText(_passwordField, password);

  final signIn = find.text('Entrar');
  await tester.ensureVisible(signIn);
  await tester.pumpAndSettle();
  await tester.tap(signIn);
  await tester.pump();
}
