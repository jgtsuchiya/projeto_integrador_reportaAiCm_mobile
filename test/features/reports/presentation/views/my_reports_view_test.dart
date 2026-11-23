import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';
import 'package:reportaai_cm/features/reports/presentation/views/my_reports_view.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/report_list_item.dart';

import '../../../../support/fake_report_repository.dart';
import '../../../../support/pump_app.dart';
import '../../../../support/report_fakes.dart';

/// O [text] dentro de um reporte da lista, e não no filtro.
Finder _inItem(String text) =>
    find.descendant(of: find.byType(ReportListItem), matching: find.text(text));

void main() {
  group('MyReportsView', () {
    late ReportFakes reports;

    setUp(() => reports = ReportFakes());

    /// Abre a lista com as rotas do novo reporte e do detalhe, que só mostram o caminho.
    Future<GoRouter> pumpView(WidgetTester tester, {bool settle = true}) async {
      final router = GoRouter(
        initialLocation: '/reportes',
        routes: [
          GoRoute(path: '/reportes', builder: (context, state) => const MyReportsView()),
          GoRoute(
            path: '/reportes/novo',
            builder: (context, state) => const Scaffold(body: Text('Tela do novo reporte')),
          ),
          GoRoute(
            path: '/reportes/:id',
            builder: (context, state) =>
                Scaffold(body: Text('Detalhe de ${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpRouter(router, overrides: reports.overrides);
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
      }
      return router;
    }

    /// Puxa a lista para baixo, como o usuário, e solta: a atualização começa.
    Future<void> pullToRefresh(WidgetTester tester, Finder scrollable) async {
      await tester.fling(scrollable, const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    testWidgets('deve mostrar o carregando da primeira página', (tester) async {
      reports.repository.listMinePending = Completer();

      await pumpView(tester, settle: false);

      expect(find.text('Carregando os reportes'), findsOneWidget);

      reports.repository.listMinePending!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('deve mostrar a lista vazia, com o "Novo reporte"', (tester) async {
      await pumpView(tester);

      expect(find.text('Você ainda não abriu nenhum reporte'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Novo reporte'));
      await tester.pumpAndSettle();

      expect(find.text('Tela do novo reporte'), findsOneWidget);
    });

    testWidgets('deve mostrar cada reporte com a miniatura, o status, as confirmações e a data '
        '(RM26)', (tester) async {
      reports.repository.mine = [
        sampleReportWith(id: 'em-validacao', description: 'Na faixa da direita'),
        sampleReportWith(id: 'confirmado', status: ReportStatus.confirmed, confirmations: 10),
      ];

      await pumpView(tester);

      expect(_inItem('Em validação'), findsOneWidget);
      expect(find.text('3 de 10 confirmações'), findsOneWidget);
      expect(_inItem('Confirmado'), findsOneWidget);
      expect(
        find.text('10 de 10 confirmações'),
        findsNothing,
        reason: 'Só no reporte em validação.',
      );
      expect(find.text('Na faixa da direita'), findsOneWidget);
      expect(find.text('Aberto em 09/11/2026'), findsNWidgets(2));
      expect(find.bySemanticsLabel(RegExp('Foto do reporte')), findsNWidgets(2));
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('deve abrir o detalhe no toque', (tester) async {
      reports.repository.mine = myReports(1);
      await pumpView(tester);

      await tester.tap(find.text('Buraco 1'));
      await tester.pumpAndSettle();

      expect(find.text('Detalhe de reporte-1'), findsOneWidget);
    });

    testWidgets('deve buscar a miniatura só dos itens que aparecem', (tester) async {
      reports.repository.mine = myReports(20);

      await pumpView(tester);

      expect(reports.repository.photoCalls.length, lessThan(20));
      expect(reports.repository.photoCalls, isNotEmpty);
    });

    testWidgets('deve mostrar um ícone no lugar da miniatura que falha, sem derrubar a lista', (
      tester,
    ) async {
      reports.repository.mine = myReports(2);
      reports.repository.photoError = const NetworkException();

      await pumpView(tester);

      expect(find.byIcon(Icons.broken_image_outlined), findsNWidgets(2));
      expect(find.text('Buraco 1'), findsOneWidget);

      reports.repository.photoError = null;
      await tester.tap(find.byIcon(Icons.broken_image_outlined).first);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });

    testWidgets('deve carregar a segunda página ao rolar até o fim', (tester) async {
      reports.repository.mine = myReports(25);
      await pumpView(tester);

      expect(find.text('Buraco 25'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Buraco 25'),
        500,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      expect(find.text('Buraco 25'), findsOneWidget);
      expect(reports.repository.listMineCalls.map((call) => call.page), [1, 2]);
    });

    testWidgets('deve mostrar o erro da segunda página no fim, sem perder a lista', (tester) async {
      reports.repository.mine = myReports(25);
      await pumpView(tester);
      reports.repository.listMineError = const NetworkException();

      await tester.scrollUntilVisible(
        find.textContaining('Os próximos reportes não carregaram'),
        500,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      expect(find.text('Buraco 20'), findsOneWidget);

      reports.repository.listMineError = null;
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Buraco 25'),
        500,
        scrollable: find.byType(Scrollable).last,
      );

      expect(find.text('Buraco 25'), findsOneWidget);
    });

    testWidgets('deve mostrar o erro da primeira página com o "Tentar de novo"', (tester) async {
      reports.repository.listMineError = const NetworkException();
      await pumpView(tester);

      expect(find.text('Os reportes não carregaram'), findsOneWidget);
      expect(find.text(NetworkException.defaultMessage), findsOneWidget);

      reports.repository.listMineError = null;
      reports.repository.mine = myReports(1);
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.text('Buraco 1'), findsOneWidget);
    });

    testWidgets('deve filtrar por status', (tester) async {
      reports.repository.mine = [
        sampleReportWith(id: 'a', description: 'Pendente'),
        sampleReportWith(id: 'b', description: 'Descartado', status: ReportStatus.rejected),
      ];
      await pumpView(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Descartados'));
      await tester.pumpAndSettle();

      expect(_inItem('Descartado'), findsNWidgets(2));
      expect(find.text('Pendente'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Confirmados'));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum reporte confirmado'), findsOneWidget);
    });

    testWidgets('deve buscar de novo no puxar para atualizar', (tester) async {
      reports.repository.mine = myReports(1);
      await pumpView(tester);
      reports.repository.mine = myReports(2);

      await pullToRefresh(tester, find.byType(ListView));

      expect(find.text('Buraco 2'), findsOneWidget);
      expect(reports.repository.listMineCalls, hasLength(2));
    });

    testWidgets('deve manter a lista e avisar quando o puxar para atualizar falha', (tester) async {
      reports.repository.mine = myReports(1);
      await pumpView(tester);
      reports.repository.listMineError = const NetworkException();

      await pullToRefresh(tester, find.byType(ListView));

      expect(find.text('Buraco 1'), findsOneWidget);
      expect(find.textContaining('A lista não foi atualizada.'), findsOneWidget);
    });

    testWidgets('deve atualizar a lista vazia no puxar para atualizar', (tester) async {
      await pumpView(tester);
      reports.repository.mine = myReports(1);

      await pullToRefresh(tester, find.byType(SingleChildScrollView).last);

      expect(find.text('Buraco 1'), findsOneWidget);
    });

    testWidgets('não deve cortar o status com a fonte em 200%', (tester) async {
      tester.usePhoneScreen(textScale: 2);
      reports.repository.mine = [
        sampleReportWith(id: 'a'),
        sampleReportWith(id: 'b', status: ReportStatus.unknown),
      ];

      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(_inItem('Em validação'), findsOneWidget);
      expect(_inItem('Em acompanhamento'), findsOneWidget);
    });

    testWidgets('deve passar nas verificações de acessibilidade', (tester) async {
      reports.repository.mine = [
        sampleReportWith(id: 'a'),
        sampleReportWith(id: 'b', status: ReportStatus.confirmed),
        sampleReportWith(id: 'c', status: ReportStatus.rejected),
        sampleReportWith(id: 'd', status: ReportStatus.unknown),
      ];
      tester.view
        ..physicalSize = const Size(800, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      await tester.pumpApp(const MyReportsView(), overrides: reports.overrides);
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  });
}
