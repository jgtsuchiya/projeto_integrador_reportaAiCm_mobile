import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/config/app_config.dart';
import 'package:reportaai_cm/main.dart' as app;

import 'support/app_steps.dart';
import 'support/pump_until.dart';
import 'support/test_api.dart';

final Finder _currentPasswordField = find.widgetWithText(TextFormField, 'Senha atual');

/// A verificação em duas etapas pelo app contra a API de verdade (RM18): ativar, entrar com o
/// código lido no Mailpit, desativar e entrar sem o código. Não roda no CI:
///
/// ```bash
/// fvm flutter test integration_test/second_factor_flow_test.dart --dart-define-from-file=env/dev.json
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('deve ativar a verificação, entrar com o código e desativar', (tester) async {
    final api = TestApi(AppConfig.fromEnvironment());
    final client = await api.registerClient();
    addTearDown(() => api.deleteClient(client));
    // A ativação exige o e-mail confirmado.
    await api.confirmClientEmail(client);

    await app.main();
    await tester.pumpAndSettle();
    expect(
      loginTitle,
      findsOneWidget,
      reason: 'O app não abriu no login. Saia da conta no aparelho e rode o teste de novo.',
    );
    await tester.signInWith(email: client.email, password: client.password);
    await tester.pumpUntilFound(find.text('Olá, Maria'), reason: 'O login não entrou.');
    await tester.pumpAndSettle();

    // Ativar: o interruptor e a senha atual.
    await tester.openAccountEntry('Verificação em duas etapas');
    await tester.tapVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.enterText(_currentPasswordField, client.password);
    await tester.tapVisible(find.widgetWithText(FilledButton, 'Ativar a verificação'));
    await tester.pumpUntilFound(
      find.text('Verificação em duas etapas ativada.'),
      reason: 'A ativação não terminou.',
    );
    // A tela da verificação ainda sai, na transição.
    await tester.pumpAndSettle();
    expect(find.text('Ativada'), findsOneWidget);

    // O login seguinte pede o código, enviado por e-mail.
    await tester.dismissSnackBars();
    await tester.signOutToLogin();
    final signedInAt = DateTime.now();
    await tester.signInWith(email: client.email, password: client.password);
    await tester.pumpUntilFound(
      find.text('Confira o seu e-mail'),
      reason: 'O login não abriu a tela do código.',
    );
    final code = await api.loginCode(client.email, after: signedInAt);
    await tester.enterText(find.widgetWithText(TextFormField, 'Código'), code);
    await tester.tapVisible(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpUntilFound(find.text('Olá, Maria'), reason: 'O código não entrou.');
    await tester.pumpAndSettle();

    // Desativar: o próximo login não pede o código.
    await tester.openAccountEntry('Verificação em duas etapas');
    await tester.tapVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.enterText(_currentPasswordField, client.password);
    await tester.tapVisible(find.widgetWithText(FilledButton, 'Desativar a verificação'));
    await tester.pumpUntilFound(
      find.text('Verificação em duas etapas desativada.'),
      reason: 'A desativação não terminou.',
    );

    await tester.dismissSnackBars();
    await tester.signOutToLogin();
    await tester.signInWith(email: client.email, password: client.password);
    await tester.pumpUntilFound(
      find.text('Olá, Maria'),
      reason: 'O login depois da desativação não entrou direto.',
    );
    expect(find.text('Confira o seu e-mail'), findsNothing);
  });
}
