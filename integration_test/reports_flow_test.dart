import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/config/app_config.dart';
import 'package:reportaai_cm/main.dart' as app;

import 'support/app_steps.dart';
import 'support/device_fakes.dart';
import 'support/pump_until.dart';
import 'support/test_api.dart';

final Finder _descriptionField = find.widgetWithText(TextFormField, 'Descrição (opcional)');
final Finder _sendButton = find.widgetWithText(FilledButton, 'Enviar');

const _description = 'Buraco do teste de integração';
const _newDescription = 'Buraco editado no teste de integração';

/// Os reportes do app contra a API de verdade: abrir um reporte com a foto de exemplo e um ponto
/// de Campo Mourão, vê-lo no detalhe (com a foto que volta da API) e na lista, editar a descrição
/// e excluir. A câmera e o GPS são os fakes do `device_fakes.dart`; o resto é de verdade. Não roda
/// no CI:
///
/// ```bash
/// fvm flutter test integration_test/reports_flow_test.dart --dart-define-from-file=env/dev.json
/// ```
///
/// A API precisa das rotas de `/api/reports` (o epic dos reportes do backend) e das migrations
/// dos reportes na base.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('deve abrir um reporte, vê-lo na lista, editar e excluir', (tester) async {
    final api = TestApi(AppConfig.fromEnvironment());
    final client = await api.registerClient();
    addTearDown(() => api.deleteClient(client));
    // Só o Client com o e-mail confirmado abre reportes (RM20).
    await api.confirmClientEmail(client);

    await app.startApp(overrides: deviceFakeOverrides());
    await tester.pumpAndSettle();
    expect(
      loginTitle,
      findsOneWidget,
      reason: 'O app não abriu no login. Saia da conta no aparelho e rode o teste de novo.',
    );
    await tester.signInWith(email: client.email, password: client.password);
    await tester.pumpUntilFound(find.text('Olá, Maria'), reason: 'O login não entrou.');
    await tester.pumpAndSettle();

    // Abrir: a câmera, a foto tratada, a localização e a busca dos reportes perto.
    await tester.tapVisible(find.widgetWithText(FilledButton, 'Novo reporte'));
    await tester.pumpUntilFound(find.text('Precisão de 8 m'), reason: 'A localização não veio.');
    final otherHole = find.text('É outro buraco');
    await tester.pumpUntil(
      () =>
          tester.widget<FilledButton>(_sendButton).onPressed != null ||
          otherHole.evaluate().isNotEmpty,
      reason: 'O "Enviar" não foi liberado: a busca dos reportes perto não terminou.',
    );
    // O reporte de uma execução que falhou antes da exclusão fica no mesmo ponto: o aviso do
    // reporte repetido aparece (RM23), e o teste segue com o reporte novo.
    if (otherHole.evaluate().isNotEmpty) {
      await tester.tapVisible(otherHole);
      await tester.pumpAndSettle();
    }
    await tester.typeInto(_descriptionField, _description);
    await tester.tapVisible(_sendButton);

    await tester.pumpUntilFound(
      find.text('0 de 10 confirmações'),
      reason: 'O reporte não abriu. Confira se a API tem as rotas e as migrations dos reportes.',
    );
    await tester.pumpUntilFound(
      find.bySemanticsLabel('Foto do buraco'),
      reason: 'A foto não voltou da API.',
    );
    await tester.pumpAndSettle();
    expect(find.text(_description), findsOneWidget);
    expect(find.text('Em validação'), findsOneWidget);
    await tester.dismissSnackBars();

    // Na lista.
    await tester.tapVisible(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tapVisible(find.text('Meus reportes'));
    await tester.pumpUntilFound(find.text(_description), reason: 'O reporte não veio na lista.');

    // Editar a descrição.
    await tester.tapVisible(find.text(_description));
    await tester.pumpUntilFound(
      find.widgetWithText(OutlinedButton, 'Editar'),
      reason: 'O detalhe não abriu com o "Editar".',
    );
    await tester.tapVisible(find.widgetWithText(OutlinedButton, 'Editar'));
    await tester.pumpAndSettle();
    await tester.typeInto(_descriptionField, _newDescription);
    await tester.tapVisible(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpUntilFound(find.text('Reporte atualizado.'), reason: 'A edição não salvou.');
    // A edição sai com uma animação: o texto dela fica na tela até o fim.
    await tester.pumpAndSettle();
    expect(find.text(_newDescription), findsOneWidget);
    await tester.dismissSnackBars();

    // Excluir: a lista fica vazia.
    await tester.tapVisible(find.widgetWithText(OutlinedButton, 'Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Excluir')));
    await tester.pumpUntilFound(
      find.text('Você ainda não abriu nenhum reporte'),
      reason: 'A exclusão não voltou para a lista vazia.',
    );
    await tester.dismissSnackBars();

    await tester.tapVisible(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.signOutToLogin();
  });
}
