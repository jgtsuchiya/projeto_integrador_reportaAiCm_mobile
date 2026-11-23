import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_draft.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/edit_report_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/views/edit_report_view.dart';
import 'package:reportaai_cm/features/reports/presentation/views/report_detail_view.dart';

import '../../../../support/fake_report_repository.dart';
import '../../../../support/pump_app.dart';
import '../../../../support/report_fakes.dart';

final Finder _saveButton = find.widgetWithText(FilledButton, 'Salvar');
final Finder _descriptionField = find.widgetWithText(TextFormField, 'Descrição (opcional)');

void main() {
  group('EditReportView', () {
    late ReportFakes reports;

    setUp(() {
      reports = ReportFakes()
        ..repository.mine = [
          sampleReportWith(id: 'reporte-1', description: 'Buraco fundo', canEdit: true),
        ];
    });

    /// Abre o detalhe e a edição por cima dele, como no app.
    Future<GoRouter> pumpView(WidgetTester tester, {bool directly = false}) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text(screenBelow)),
          ),
          GoRoute(
            path: '/reportes/:id',
            builder: (context, state) => ReportDetailView(reportId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'editar',
                builder: (context, state) => EditReportView(reportId: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpRouter(router, overrides: reports.overrides);
      if (directly) {
        // Um deep link: o detalhe é montado embaixo, junto com a edição.
        router.go('/reportes/reporte-1/editar');
      } else {
        unawaited(router.push('/reportes/reporte-1'));
        await tester.pumpAndSettle();
        unawaited(router.push('/reportes/reporte-1/editar'));
      }
      await tester.pumpAndSettle();
      return router;
    }

    Future<void> tapVisible(WidgetTester tester, Finder target) async {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    bool isEnabled(WidgetTester tester, Finder button) =>
        tester.widget<ButtonStyleButton>(button).onPressed != null;

    testWidgets('deve começar com a descrição, a foto atual e o aviso da localização', (
      tester,
    ) async {
      await pumpView(tester);

      expect(find.text('Buraco fundo'), findsOneWidget);
      expect(find.bySemanticsLabel('Foto atual do buraco'), findsOneWidget);
      expect(find.textContaining('A localização não muda.'), findsOneWidget);
      expect(isEnabled(tester, _saveButton), isFalse);
    });

    testWidgets('deve preencher a descrição também num deep link', (tester) async {
      await pumpView(tester, directly: true);

      expect(find.text('Buraco fundo'), findsOneWidget);
    });

    testWidgets('deve salvar só a descrição e voltar ao detalhe atualizado', (tester) async {
      await pumpView(tester);

      await tester.enterText(_descriptionField, 'Bem fundo');
      await tester.pump();
      await tapVisible(tester, _saveButton);

      expect(
        reports.repository.updateCalls.single.changes,
        const ReportChanges(description: 'Bem fundo'),
      );
      expect(find.byType(ReportDetailView), findsOneWidget);
      expect(find.text('Bem fundo'), findsOneWidget);
      expect(find.text(EditReportViewModel.savedMessage), findsOneWidget);
    });

    testWidgets('deve trocar a foto e mostrar a nova no detalhe, pelo id novo', (tester) async {
      await pumpView(tester);

      await tapVisible(tester, find.text('Trocar a foto'));

      expect(find.bySemanticsLabel('Foto nova do buraco, ainda não salva'), findsOneWidget);
      expect(isEnabled(tester, _saveButton), isTrue);

      await tapVisible(tester, _saveButton);

      final changes = reports.repository.updateCalls.single.changes;
      expect(changes.description, isNull);
      expect(changes.photo, isNotNull);
      expect(
        reports.repository.photoCalls.where((call) => call.size == ReportPhotoSize.full),
        hasLength(2),
        reason: 'A foto do id novo é buscada de novo: o cache não mostra a antiga.',
      );
    });

    testWidgets('deve voltar ao detalhe atualizado com a message do 422', (tester) async {
      await pumpView(tester);
      reports.repository.updateError = const BusinessRuleException(
        message: 'O reporte já recebeu votos e não pode mais ser editado.',
      );
      reports.repository.mine = [
        sampleReportWith(id: 'reporte-1', description: 'Buraco fundo', confirmations: 1),
      ];

      await tester.enterText(_descriptionField, 'Nova');
      await tester.pump();
      await tapVisible(tester, _saveButton);

      expect(find.byType(ReportDetailView), findsOneWidget);
      expect(find.text('O reporte já recebeu votos e não pode mais ser editado.'), findsOneWidget);
      expect(find.text('1 de 10 confirmações'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Editar'), findsNothing);
    });

    testWidgets('deve continuar na tela sem conexão, com o aviso', (tester) async {
      await pumpView(tester);
      reports.repository.updateError = const NetworkException();

      await tester.enterText(_descriptionField, 'Nova');
      await tester.pump();
      await tapVisible(tester, _saveButton);

      expect(find.byType(EditReportView), findsOneWidget);
      expect(find.text(NetworkException.defaultMessage), findsOneWidget);
    });

    testWidgets('deve perguntar antes de descartar as alterações', (tester) async {
      await pumpView(tester);
      await tester.enterText(_descriptionField, 'Nova');
      await tester.pump();

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Descartar as alterações?'), findsOneWidget);

      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();

      expect(find.byType(ReportDetailView), findsOneWidget);
      expect(reports.repository.updateCalls, isEmpty);
    });

    testWidgets('deve avisar o reporte que não pode mais ser editado', (tester) async {
      reports.repository.mine = [sampleReportWith(id: 'reporte-1', status: ReportStatus.confirmed)];

      await pumpView(tester, directly: true);

      expect(find.text('Este reporte não pode mais ser editado'), findsOneWidget);
    });

    testWidgets('deve aguentar a fonte em 200%', (tester) async {
      tester.usePhoneScreen(textScale: 2);

      await pumpView(tester);
      await tester.ensureVisible(_saveButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('deve passar nas verificações de acessibilidade (${themeMode.name})', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(800, 2400)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        await tester.pumpApp(
          const Stack(
            children: [
              // O detalhe embaixo, que traz o reporte, como na pilha das telas.
              Offstage(child: ReportDetailView(reportId: 'reporte-1')),
              EditReportView(reportId: 'reporte-1'),
            ],
          ),
          overrides: reports.overrides,
          themeMode: themeMode,
        );
        await tester.pumpAndSettle();

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      });
    }
  });
}
