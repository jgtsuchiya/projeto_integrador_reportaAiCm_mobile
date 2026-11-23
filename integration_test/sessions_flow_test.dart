import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/config/app_config.dart';
import 'package:reportaai_cm/main.dart' as app;

import 'support/app_steps.dart';
import 'support/pump_until.dart';
import 'support/test_api.dart';

/// As sessões abertas pelo app contra a API de verdade (RM19): a deste aparelho, com o
/// `User-Agent` do app, e a de outro lugar, que o app encerra e que deixa de renovar. Não roda no
/// CI:
///
/// ```bash
/// fvm flutter test integration_test/sessions_flow_test.dart --dart-define-from-file=env/dev.json
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('deve listar as sessões e encerrar a de outro lugar', (tester) async {
    final api = TestApi(AppConfig.fromEnvironment());
    final client = await api.registerClient();
    addTearDown(() => api.deleteClient(client));
    // Uma sessão aberta em outro lugar, como o `api.http`: sem o User-Agent do app.
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

    await tester.openAccountEntry('Sessões abertas');
    await tester.pumpUntilFound(find.text('Este aparelho'), reason: 'A lista não carregou.');

    // A sessão deste aparelho tem o User-Agent do app, e a outra, o padrão do Dart.
    expect(find.textContaining('App ReportaAi ('), findsOneWidget);
    expect(find.text('Aparelho desconhecido'), findsOneWidget);

    await tester.tapVisible(find.text('Encerrar'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Encerrar')),
    );
    await tester.pumpUntilGone(
      find.text('Aparelho desconhecido'),
      reason: 'A outra sessão não saiu da lista.',
    );

    expect(await api.refreshStatus(other.refreshToken), 401);
    expect(find.text('Este aparelho'), findsOneWidget);
  });
}
