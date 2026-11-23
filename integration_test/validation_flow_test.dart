import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/config/app_config.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/nearby_report_item.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/report_list_item.dart';
import 'package:reportaai_cm/main.dart' as app;

import 'fixtures/report_photo.dart';
import 'support/app_steps.dart';
import 'support/device_fakes.dart';
import 'support/pump_until.dart';
import 'support/test_api.dart';

/// A validação dos reportes contra a API de verdade, com dois Clients: o autor abre o reporte por
/// fora do app (o `TestApi`), e o outro o encontra nos "Reportes perto de você" e confirma pela
/// tela. Depois, o autor entra no app e vê "1 de 10 confirmações" em "Meus reportes". O GPS é o
/// fake do `device_fakes.dart`, no mesmo ponto do reporte; o resto é de verdade. Não roda no CI:
///
/// ```bash
/// fvm flutter test integration_test/validation_flow_test.dart --dart-define-from-file=env/dev.json
/// ```
///
/// A API precisa dos dois epics dos reportes do backend (as rotas de `/api/reports` e o voto) e das
/// migrations deles na base.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('deve confirmar pela tela o reporte de outro cidadão, e o autor vê a confirmação', (
    tester,
  ) async {
    final api = TestApi(AppConfig.fromEnvironment());
    final author = await api.registerClient();
    addTearDown(() => api.deleteClient(author));
    final voter = await api.registerClient();
    addTearDown(() => api.deleteClient(voter));
    // Só o Client com o e-mail confirmado abre e vota (RM20).
    await api.confirmClientEmail(author);
    await api.confirmClientEmail(voter);

    // A descrição única acha o reporte entre os de outras execuções, no mesmo ponto.
    final description = 'Buraco da validação ${DateTime.now().millisecondsSinceEpoch}';
    final reportId = await api.openReport(
      author,
      description: description,
      latitude: campoMouraoLatitude,
      longitude: campoMouraoLongitude,
      photo: reportPhotoFixture,
    );
    // Antes da exclusão das contas: o `addTearDown` roda do último para o primeiro.
    addTearDown(() => api.deleteReport(author, reportId));

    await app.startApp(overrides: deviceFakeOverrides());
    await tester.pumpAndSettle();
    expect(
      loginTitle,
      findsOneWidget,
      reason: 'O app não abriu no login. Saia da conta no aparelho e rode o teste de novo.',
    );

    // O outro cidadão encontra o reporte perto dele e confirma.
    await tester.signInWith(email: voter.email, password: voter.password);
    await tester.pumpUntilFound(find.text('Olá, Maria'), reason: 'O login não entrou.');
    await tester.pumpAndSettle();
    await tester.tapVisible(find.text('Reportes perto de você'));
    await tester.pumpUntilFound(
      find.textContaining('Em validação a até 500 m de você'),
      reason: 'A lista dos reportes perto não carregou. Confira se a API tem o voto (epic 2).',
    );
    final item = find.ancestor(of: find.text(description), matching: find.byType(NearbyReportItem));
    await tester.scrollUntilVisible(
      find.text(description),
      300,
      scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)),
    );
    await tester.pumpAndSettle();
    expect(find.descendant(of: item, matching: find.text('0 de 10 confirmações')), findsOneWidget);

    await tester.tapVisible(
      find.descendant(of: item, matching: find.widgetWithText(FilledButton, 'Está lá')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Confirmar')),
    );
    await tester.pumpUntilFound(
      find.descendant(of: item, matching: find.text('Você confirmou')),
      reason: 'O voto não foi registrado.',
    );
    await tester.pumpAndSettle();
    expect(find.descendant(of: item, matching: find.text('1 de 10 confirmações')), findsOneWidget);
    await tester.dismissSnackBars();

    await tester.tapVisible(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.signOutToLogin();

    // O autor vê a confirmação em "Meus reportes".
    await tester.signInWith(email: author.email, password: author.password);
    await tester.pumpUntilFound(find.text('Olá, Maria'), reason: 'O login do autor não entrou.');
    await tester.pumpAndSettle();
    await tester.tapVisible(find.text('Meus reportes'));
    await tester.pumpUntilFound(find.text(description), reason: 'O reporte não veio na lista.');
    expect(
      find.descendant(
        of: find.ancestor(of: find.text(description), matching: find.byType(ReportListItem)),
        matching: find.text('1 de 10 confirmações'),
      ),
      findsOneWidget,
    );

    await tester.tapVisible(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.signOutToLogin();
  });
}
