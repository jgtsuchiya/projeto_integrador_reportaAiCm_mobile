import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reportaai_cm/main.dart' as app;

/// Fluxo ponta a ponta contra a API de verdade: o app inteiro, num emulador ou aparelho, com a
/// API local no ar. Não roda no CI (ver docs/TESTING.md):
///
/// ```bash
/// fvm flutter test integration_test --dart-define-from-file=env/dev.json
/// ```
///
/// O atalho do diagnóstico fica no login: o aparelho não pode ter uma sessão guardada.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('deve mostrar "ok" no diagnóstico com a API local no ar', (tester) async {
    await app.main();
    await tester.pumpAndSettle();

    expect(
      find.text('Diagnóstico da API'),
      findsOneWidget,
      reason: 'O app não abriu no login. Saia da conta no aparelho e rode o teste de novo.',
    );

    await tester.tap(find.text('Diagnóstico da API'));
    await tester.pumpAndSettle();

    expect(
      find.text('ok'),
      findsOneWidget,
      reason: 'A API não respondeu. Confira se ela está no ar e a API_URL do env/dev.json.',
    );
  });
}
