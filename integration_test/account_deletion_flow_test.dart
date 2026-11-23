import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/config/app_config.dart';
import 'package:reportaai_cm/main.dart' as app;

import 'support/app_steps.dart';
import 'support/pump_until.dart';
import 'support/test_api.dart';

final Finder _currentPasswordField = find.widgetWithText(TextFormField, 'Senha atual');
final Finder _delete = find.widgetWithText(FilledButton, 'Excluir minha conta');

/// A exclusão da conta pelo app contra a API de verdade (RM17): a senha errada aparece no campo,
/// a certa exclui e volta ao login com o aviso, o login da conta excluída é recusado, e o mesmo
/// e-mail e CPF se cadastram de novo. Precisa da API com a T8 do backend. Não roda no CI:
///
/// ```bash
/// fvm flutter test integration_test/account_deletion_flow_test.dart --dart-define-from-file=env/dev.json
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('deve excluir a conta pela tela e liberar o e-mail para um novo cadastro', (
    tester,
  ) async {
    final api = TestApi(AppConfig.fromEnvironment());
    final client = await api.registerClient();
    // A conta excluída pela tela já não existe; a cadastrada de novo, sim.
    addTearDown(() => api.deleteClient(client, ifExists: true));

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

    await tester.openAccountEntry('Excluir conta');
    await tester.enterText(_currentPasswordField, 'senha-errada-1');
    await tester.tapVisible(find.byType(CheckboxListTile));
    await tester.tapVisible(_delete);
    await tester.pumpUntilFound(
      find.text('Senha atual incorreta.'),
      reason: 'A senha errada não apareceu no campo.',
    );
    expect(find.text('Sua sessão expirou. Entre de novo.'), findsNothing);

    await tester.typeInto(_currentPasswordField, client.password);
    await tester.tapVisible(_delete);
    await tester.pumpUntilFound(loginTitle, reason: 'A exclusão não voltou ao login.');
    await tester.pumpAndSettle();

    // O motivo é o da exclusão, e não o da sessão expirada (RM07).
    expect(find.text('Sua conta foi excluída.'), findsOneWidget);
    expect(find.text('Sua sessão expirou. Entre de novo.'), findsNothing);

    // O login da conta excluída é recusado, como o de uma conta que não existe.
    await tester.signInWith(email: client.email, password: client.password);
    await tester.pumpUntilFound(
      find.text('E-mail ou senha incorretos.'),
      reason: 'O login da conta excluída não foi recusado.',
    );

    // O e-mail e o CPF ficam livres para um novo cadastro.
    await api.registerClient(client);
  });
}
