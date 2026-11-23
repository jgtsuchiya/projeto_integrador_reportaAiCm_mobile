import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/config/app_config.dart';
import 'package:reportaai_cm/main.dart' as app;

import '../test/support/app_lifecycle.dart';
import 'support/pump_until.dart';
import 'support/test_api.dart';

final Finder _loginTitle = find.text('Entrar no ReportaAi Cm');
final Finder _verifyEmail = find.text('Confirme o seu e-mail');

/// O cadastro do Client pelo app contra a API de verdade: o app inteiro, num emulador ou aparelho,
/// com o SDK do SuperTokens, a API local e o Mailpit no ar. Não roda no CI (ver docs/TESTING.md):
///
/// ```bash
/// fvm flutter test integration_test/registration_flow_test.dart --dart-define-from-file=env/dev.json
/// ```
///
/// A conta é criada pela tela, com um e-mail e um CPF novos, e excluída no fim, mesmo quando o
/// teste falha. O aparelho não pode ter uma sessão guardada.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'deve criar a conta pelo app, entrar sozinho e tirar o aviso depois de confirmar o e-mail',
    (tester) async {
      final api = TestApi(AppConfig.fromEnvironment());
      final client = api.newClient();
      addTearDown(() => api.deleteClient(client, ifExists: true));

      await app.main();
      await tester.pumpAndSettle();
      expect(
        _loginTitle,
        findsOneWidget,
        reason: 'O app não abriu no login. Saia da conta no aparelho e rode o teste de novo.',
      );

      await _tap(tester, find.text('Criar conta'));
      await tester.pumpAndSettle();

      // Os campos com máscara recebem só os dígitos, como o usuário digita.
      for (final (label, text) in [
        ('Nome completo', client.name),
        ('E-mail', client.email),
        ('Senha', client.password),
        ('CPF', client.cpf),
        ('Telefone', '44999998888'),
        ('Data de nascimento', '20051990'),
      ]) {
        await tester.enterText(find.widgetWithText(TextFormField, label), text);
      }
      await _tap(tester, find.widgetWithText(FilledButton, 'Criar conta'));

      // O cadastro e o login automático (RM12), com o aviso e a espera do reenvio (RM14).
      await tester.pumpUntilFound(
        find.text('Olá, Maria'),
        reason: 'O cadastro não chegou à tela inicial.',
      );
      expect(_verifyEmail, findsOneWidget);
      expect(find.textContaining('Reenviar e-mail em'), findsOneWidget);

      // O Client abre o link do e-mail no navegador, e a página do painel confirma o e-mail.
      final token = await api.emailVerificationToken(client.email);
      await api.confirmEmail(token);

      // De volta ao app, o aviso some sozinho, sem puxar para atualizar (RM14).
      tester.leaveAndComeBack();
      await tester.pumpUntilGone(
        _verifyEmail,
        reason: 'O aviso do e-mail não sumiu depois da confirmação.',
      );
      expect(find.text('Olá, Maria'), findsOneWidget);
    },
  );
}

/// Toca no [target], rolando a tela até ele: com o teclado aberto, o botão pode ficar fora dela.
Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pump();
}
