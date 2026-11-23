import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/config/app_config.dart';
import 'package:reportaai_cm/main.dart' as app;

import 'support/app_steps.dart';
import 'support/pump_until.dart';
import 'support/test_api.dart';

const _newPassword = 'senha-nova-2';

final Finder _currentPasswordField = find.widgetWithText(TextFormField, 'Senha atual');

/// A troca de senha pelo app contra a API de verdade (RM15 e RM16): a senha atual errada aparece
/// no campo, sem levar ao login, a sessão de outro lugar deixa de renovar, e a senha nova entra.
/// Precisa da API com a T8 do backend (a senha errada responde 422). Não roda no CI:
///
/// ```bash
/// fvm flutter test integration_test/password_change_flow_test.dart --dart-define-from-file=env/dev.json
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('deve trocar a senha, derrubar a outra sessão e entrar com a senha nova', (
    tester,
  ) async {
    final api = TestApi(AppConfig.fromEnvironment());
    final client = await api.registerClient();
    addTearDown(
      () => api.deleteClient(client, password: _newPassword, fallbackPassword: client.password),
    );
    // Uma sessão aberta em outro lugar, como o `api.http`.
    final other = (await api.signIn(client))!;

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

    await tester.openAccountEntry('Trocar senha');

    // A senha atual errada: o 422 da API aparece no campo, sem levar ao login (RM15).
    await tester.enterText(_currentPasswordField, 'senha-errada-1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Senha nova'), _newPassword);
    await tester.enterText(find.widgetWithText(TextFormField, 'Repita a senha nova'), _newPassword);
    await tester.tapVisible(find.widgetWithText(FilledButton, 'Trocar senha'));
    await tester.pumpUntilFound(
      find.text('Senha atual incorreta.'),
      reason: 'A senha atual errada não apareceu no campo.',
    );
    expect(find.text('Sua sessão expirou. Entre de novo.'), findsNothing);
    expect(await api.refreshStatus(other.refreshToken), 200);

    await tester.enterText(_currentPasswordField, client.password);
    await tester.tapVisible(find.widgetWithText(FilledButton, 'Trocar senha'));
    await tester.pumpUntilFound(
      find.text('Senha alterada. Os outros aparelhos vão precisar entrar de novo.'),
      reason: 'A troca de senha não terminou.',
    );

    // A outra sessão deixa de renovar, e a deste aparelho continua (RM16).
    expect(await api.refreshStatus(other.refreshToken), 401);
    expect(find.text('Minha conta'), findsOneWidget);

    await tester.dismissSnackBars();
    await tester.signOutToLogin();
    await tester.signInWith(email: client.email, password: _newPassword);
    await tester.pumpUntilFound(
      find.text('Olá, Maria'),
      reason: 'O login com a senha nova não entrou.',
    );
  });
}
