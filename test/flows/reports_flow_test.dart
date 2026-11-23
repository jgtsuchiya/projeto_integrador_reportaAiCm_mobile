import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/routes.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/home/presentation/views/home_view.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/edit_report_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_detail_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/views/edit_report_view.dart';
import 'package:reportaai_cm/features/reports/presentation/views/my_reports_view.dart';
import 'package:reportaai_cm/features/reports/presentation/views/new_report_view.dart';
import 'package:reportaai_cm/features/reports/presentation/views/report_detail_view.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/report_list_item.dart';

import '../support/app_flow.dart';
import '../support/auth_fakes.dart';
import '../support/fake_location_service.dart';
import '../support/fake_profile_repository.dart';
import '../support/fake_report_repository.dart';
import '../support/pump_app.dart';
import '../support/report_fakes.dart';

final Finder _sendButton = find.widgetWithText(FilledButton, 'Enviar');
final Finder _descriptionField = find.widgetWithText(TextFormField, 'Descrição (opcional)');

/// Os fluxos do epic dos reportes de ponta a ponta, com o app inteiro: as rotas, as telas, o
/// `AuthController` e os ViewModels de verdade, e só a sessão, a API, a câmera, o tratamento da
/// foto e o GPS trocados pelos fakes. Os detalhes de cada tela ficam nos testes dela.
void main() {
  group('Fluxo dos reportes', () {
    late AuthFakes auth;
    late ReportFakes reports;

    setUp(() {
      auth = verifiedAuthFakes();
      reports = ReportFakes();
    });

    /// Abre o app com o Client dentro, na tela inicial.
    Future<List<String>> openHome(WidgetTester tester) async {
      final history = RouteHistory();
      await tester.pumpWholeApp(
        overrides: [...auth.overrides, ...reports.overrides],
        observers: [history],
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeView), findsOneWidget);
      return history.routes;
    }

    /// Da tela inicial, abre o "Novo reporte": a câmera, a foto e a localização, pelos fakes.
    Future<void> openNewReport(WidgetTester tester) async {
      await _tapAndSettle(tester, find.widgetWithText(FilledButton, 'Novo reporte'));
      expect(find.byType(NewReportView), findsOneWidget);
    }

    testWidgets('deve abrir um reporte pela tela inicial, ver o detalhe e achá-lo em "Meus '
        'reportes" (RM21, RM22 e RM24)', (tester) async {
      final routes = await openHome(tester);

      await openNewReport(tester);

      expect(reports.camera.calls, 1);
      expect(find.text('Precisão de 8 m'), findsOneWidget);

      await tester.enterText(_descriptionField, 'Na faixa da direita');
      await _tapAndSettle(tester, _sendButton);

      final sent = reports.repository.createCalls.single;
      expect(sent.draft.description, 'Na faixa da direita');
      expect(sent.draft.location.accuracyMeters, 8);
      expect(find.byType(ReportDetailView), findsOneWidget);
      expect(find.text('Na faixa da direita'), findsOneWidget);
      expect(find.text('0 de 10 confirmações'), findsOneWidget);
      expect(
        find.text('Reporte enviado. Agora ele precisa de 10 confirmações de outros cidadãos.'),
        findsOneWidget,
      );

      // O detalhe tomou o lugar do formulário: o "voltar" vai para a tela inicial.
      await _tapAndSettle(tester, find.byType(BackButton));
      expect(find.byType(HomeView), findsOneWidget);

      await _tapAndSettle(tester, find.text('Meus reportes'));

      expect(find.byType(MyReportsView), findsOneWidget);
      expect(find.text('Na faixa da direita'), findsOneWidget);
      expect(routes, [
        AppRoutes.splash,
        AppRoutes.home,
        AppRoutes.newReport,
        AppRoutes.reportDetail('novo-1'),
        AppRoutes.home,
        AppRoutes.reports,
      ]);
    });

    testWidgets('deve liberar o envio depois do "Atualizar localização" com a localização '
        'precisa (RM21)', (tester) async {
      reports.location.position = campoMouraoPositionWith(accuracyMeters: 120);
      await openHome(tester);
      await openNewReport(tester);

      expect(find.text('A localização está imprecisa'), findsOneWidget);
      expect(tester.widget<FilledButton>(_sendButton).onPressed, isNull);

      reports.location.position = campoMouraoPosition;
      await _tapAndSettle(tester, find.text('Atualizar localização'));
      await _tapAndSettle(tester, _sendButton);

      expect(reports.repository.createCalls.single.draft.location.accuracyMeters, 8);
      expect(find.byType(ReportDetailView), findsOneWidget);
    });

    testWidgets('deve seguir com o reporte novo no "É outro buraco" (RM23)', (tester) async {
      reports.repository.nearby = [othersReport()];
      await openHome(tester);
      await openNewReport(tester);

      expect(find.text('Já existe um reporte a 12 m daqui'), findsOneWidget);

      await _tapAndSettle(tester, find.text('É outro buraco'));
      await _tapAndSettle(tester, _sendButton);

      expect(reports.repository.createCalls, hasLength(1));
      expect(find.byType(ReportDetailView), findsOneWidget);
    });

    testWidgets('deve abrir o reporte já aberto no "Ver o reporte", sem abrir outro (RM23)', (
      tester,
    ) async {
      reports.repository.nearby = [othersReport()];
      await openHome(tester);
      await openNewReport(tester);

      await _tapAndSettle(tester, find.text('Ver o reporte'));

      expect(find.byType(ReportDetailView), findsOneWidget);
      expect(find.text('A 12 m de você'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Excluir'), findsNothing);
      expect(reports.repository.createCalls, isEmpty);

      // De volta ao formulário, a foto e a localização continuam lá.
      await _tapAndSettle(tester, find.byType(BackButton));
      expect(find.byType(NewReportView), findsOneWidget);
      expect(find.bySemanticsLabel('Foto do buraco que você tirou'), findsOneWidget);
    });

    testWidgets('deve mostrar o aviso com o reenvio sem o e-mail confirmado, e abrir a câmera '
        'depois da confirmação (RM20)', (tester) async {
      auth = AuthFakes(signedIn: true);
      await openHome(tester);

      expect(find.text('Confirme o seu e-mail'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Novo reporte'), findsNothing);

      // A lista mostra o "Novo reporte", e a tela dele mostra o aviso no lugar do formulário.
      await _tapAndSettle(tester, find.text('Meus reportes'));
      await _tapAndSettle(tester, find.widgetWithText(FilledButton, 'Novo reporte'));

      expect(find.byType(NewReportView), findsOneWidget);
      expect(find.text('Reenviar e-mail'), findsOneWidget);
      expect(reports.camera.calls, 0);

      auth.profile.result = clientProfileWith(emailVerifiedAt: emailVerifiedAt);
      await tester.container().read(authControllerProvider.notifier).refreshProfile();
      await tester.pumpAndSettle();

      expect(reports.camera.calls, 1);
      expect(_sendButton, findsOneWidget);
    });

    testWidgets('deve editar a descrição pelo detalhe e voltar ao detalhe atualizado (RM25)', (
      tester,
    ) async {
      reports.repository.mine = [
        sampleReportWith(id: 'reporte-1', description: 'Buraco fundo', canEdit: true),
      ];
      await openHome(tester);
      await _tapAndSettle(tester, find.text('Meus reportes'));
      await _tapAndSettle(tester, find.text('Buraco fundo'));

      await _tapAndSettle(tester, find.widgetWithText(OutlinedButton, 'Editar'));
      expect(find.byType(EditReportView), findsOneWidget);

      await tester.enterText(_descriptionField, 'Buraco muito fundo');
      await tester.pump();
      await _tapAndSettle(tester, find.widgetWithText(FilledButton, 'Salvar'));

      expect(find.byType(ReportDetailView), findsOneWidget);
      expect(find.text('Buraco muito fundo'), findsOneWidget);
      expect(find.text(EditReportViewModel.savedMessage), findsOneWidget);

      await _tapAndSettle(tester, find.byType(BackButton));

      expect(find.byType(MyReportsView), findsOneWidget);
      expect(
        find.descendant(of: find.byType(ReportListItem), matching: find.text('Buraco muito fundo')),
        findsOneWidget,
      );
    });

    testWidgets('deve excluir pelo detalhe e voltar à lista sem o reporte (RM25)', (tester) async {
      reports.repository.mine = myReports(2);
      await openHome(tester);
      await _tapAndSettle(tester, find.text('Meus reportes'));
      await _tapAndSettle(tester, find.text('Buraco 1'));

      await _tapAndSettle(tester, find.widgetWithText(OutlinedButton, 'Excluir'));
      await _tapAndSettle(
        tester,
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Excluir')),
      );

      expect(find.byType(MyReportsView), findsOneWidget);
      expect(find.text(ReportDetailViewModel.deletedMessage), findsOneWidget);
      expect(find.text('Buraco 1'), findsNothing);
      expect(find.text('Buraco 2'), findsOneWidget);
    });
  });
}

/// Toca no [target], rolando a tela até ele, e espera a tela parar de mudar.
Future<void> _tapAndSettle(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}
