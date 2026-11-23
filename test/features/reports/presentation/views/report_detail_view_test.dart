import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_draft.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';
import 'package:reportaai_cm/features/reports/domain/models/vote_type.dart';
import 'package:reportaai_cm/features/reports/presentation/views/report_detail_view.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_report_repository.dart';
import '../../../../support/pump_app.dart';
import '../../../../support/report_fakes.dart';

final Finder _editButton = find.widgetWithText(OutlinedButton, 'Editar');
final Finder _deleteButton = find.widgetWithText(OutlinedButton, 'Excluir');
final Finder _confirmVoteButton = find.widgetWithText(FilledButton, 'Está lá');

void main() {
  group('ReportDetailView', () {
    late AuthFakes auth;
    late ReportFakes reports;

    setUp(() {
      auth = verifiedAuthFakes();
      reports = ReportFakes();
    });

    /// Abre o detalhe do [id] por cima de outra tela, como pela lista, com a edição embaixo dele.
    Future<GoRouter> pumpView(
      WidgetTester tester, {
      String id = 'reporte-1',
      Object? extra,
      bool settle = true,
    }) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text(screenBelow)),
          ),
          GoRoute(
            path: '/reportes/:id',
            builder: (context, state) => ReportDetailView(
              reportId: state.pathParameters['id']!,
              distanceMeters: state.extra as int?,
            ),
            routes: [
              GoRoute(
                path: 'editar',
                builder: (context, state) => const Scaffold(body: Text('Tela da edição')),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpRouter(router, overrides: [...auth.overrides, ...reports.overrides]);
      // O router do app só abre o detalhe com o Client dentro.
      AuthFakes.startAuth(tester.container());
      await tester.pumpAndSettle();
      unawaited(router.push('/reportes/$id', extra: extra));
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
      }
      return router;
    }

    Future<void> tapVisible(WidgetTester tester, Finder target) async {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    testWidgets('deve mostrar o carregando', (tester) async {
      reports.repository.mine = [sampleReportWith(id: 'reporte-1')];
      reports.repository.getByIdPending = Completer();

      await pumpView(tester, settle: false);
      await tester.pump();

      expect(find.text('Carregando o reporte'), findsOneWidget);

      reports.repository.getByIdPending!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('deve mostrar a foto, o status, o progresso, a descrição, as datas e a precisão '
        '(RM26)', (tester) async {
      reports.repository.mine = [sampleReportWith(id: 'reporte-1')];

      await pumpView(tester);

      expect(find.bySemanticsLabel(RegExp('Foto do buraco')), findsOneWidget);
      expect(find.text('Em validação'), findsOneWidget);
      expect(find.text('3 de 10 confirmações'), findsOneWidget);
      expect(find.text('Buraco grande na faixa da direita, perto do semáforo.'), findsOneWidget);
      expect(find.textContaining('Aberto em 09/11/2026'), findsOneWidget);
      expect(find.text('Precisão de 9 m'), findsOneWidget);
      expect(find.text('A localização não muda depois da abertura.'), findsOneWidget);
      expect(reports.repository.photoCalls.single.size, ReportPhotoSize.full);
    });

    testWidgets('deve mostrar o "Editar" e o "Excluir" só quando a API permite (RM25)', (
      tester,
    ) async {
      reports.repository.mine = [sampleReportWith(id: 'reporte-1', canEdit: true)];
      await pumpView(tester);

      expect(_editButton, findsOneWidget);
      expect(_deleteButton, findsOneWidget);
    });

    testWidgets('não deve mostrar as ações que a API não permite', (tester) async {
      reports.repository.mine = [
        sampleReportWith(id: 'reporte-1', status: ReportStatus.confirmed, canDelete: false),
      ];
      await pumpView(tester);

      expect(_editButton, findsNothing);
      expect(_deleteButton, findsNothing);
    });

    testWidgets('deve mostrar o reporte confirmado com a data e o descartado com o motivo', (
      tester,
    ) async {
      reports.repository.mine = [
        sampleReportWith(
          id: 'confirmado',
          status: ReportStatus.confirmed,
          confirmations: 10,
          statusChangedAt: DateTime.utc(2026, 11, 10, 15),
        ),
        sampleReportWith(id: 'descartado', status: ReportStatus.rejected),
        sampleReportWith(id: 'outro-status', status: ReportStatus.unknown),
      ];

      await pumpView(tester, id: 'confirmado');

      expect(find.text('Confirmado'), findsOneWidget);
      expect(find.text('Confirmado por outros cidadãos em 10/11/2026'), findsOneWidget);
      expect(find.textContaining('confirmações'), findsNothing);
      expect(find.textContaining('Status mudou em 10/11/2026'), findsOneWidget);

      await pumpView(tester, id: 'descartado');

      expect(find.text('Descartado'), findsOneWidget);
      expect(find.text('Outros cidadãos não encontraram o buraco'), findsOneWidget);

      await pumpView(tester, id: 'outro-status');

      expect(find.text('Em acompanhamento'), findsOneWidget);
    });

    testWidgets('deve mostrar a distância, o voto e nenhuma ação do autor no reporte de outro '
        'cidadão (RM27)', (tester) async {
      reports.repository.others = [othersReport(id: 'reporte-1')];

      await pumpView(tester, extra: 12);

      expect(find.text('A 12 m de você'), findsOneWidget);
      expect(find.text('A localização não muda depois da abertura.'), findsNothing);
      expect(_editButton, findsNothing);
      expect(_deleteButton, findsNothing);
      expect(find.text('O buraco ainda está lá?'), findsOneWidget);
      expect(_confirmVoteButton, findsOneWidget);
    });

    testWidgets('não deve mostrar o voto no próprio reporte', (tester) async {
      reports.repository.mine = [sampleReportWith(id: 'reporte-1')];

      await pumpView(tester);

      expect(find.text('O buraco ainda está lá?'), findsNothing);
      expect(_confirmVoteButton, findsNothing);
    });

    group('voto', () {
      Future<void> vote(WidgetTester tester) async {
        await tapVisible(tester, _confirmVoteButton);
        await tester.tap(
          find.descendant(of: find.byType(AlertDialog), matching: find.text('Confirmar')),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('deve mostrar a contagem e o voto novos, sem buscar o reporte de novo (RM30)', (
        tester,
      ) async {
        reports.repository.others = [othersReport(id: 'reporte-1')];
        await pumpView(tester, extra: 12);

        await vote(tester);

        expect(find.text('4 de 10 confirmações'), findsOneWidget);
        expect(find.text('Você confirmou'), findsOneWidget);
        expect(_confirmVoteButton, findsNothing);
        expect(find.text('A 12 m de você'), findsOneWidget, reason: 'A distância continua.');
        expect(reports.repository.getByIdCalls, hasLength(1));
      });

      testWidgets('deve mostrar "Confirmado" depois do voto que chega a 10, sem recarregar a tela '
          '(RM30)', (tester) async {
        reports.repository.others = [othersReport(id: 'reporte-1', confirmations: 9)];
        await pumpView(tester);

        await vote(tester);

        expect(find.text('Confirmado'), findsOneWidget);
        expect(find.text('Confirmado por outros cidadãos em 22/11/2026'), findsOneWidget);
        expect(find.text('Você confirmou'), findsOneWidget);
        expect(find.text('Voto registrado. Com ele, o reporte foi confirmado.'), findsOneWidget);
        expect(reports.repository.getByIdCalls, hasLength(1));
      });

      testWidgets('deve mostrar o voto já dado ao abrir', (tester) async {
        reports.repository.others = [othersReport(id: 'reporte-1', myVote: VoteType.deny)];

        await pumpView(tester);

        expect(find.text('Você disse que não está lá'), findsOneWidget);
      });

      testWidgets('deve mostrar o aviso do e-mail no lugar do voto (RM20)', (tester) async {
        auth = AuthFakes(signedIn: true);
        reports.repository.others = [othersReport(id: 'reporte-1')];

        await pumpView(tester);

        expect(find.text('Confirme o seu e-mail'), findsOneWidget);
        expect(_confirmVoteButton, findsNothing);
      });

      testWidgets('deve mostrar "Reporte não encontrado" quando o reporte some no meio do voto', (
        tester,
      ) async {
        reports.repository.others = [othersReport(id: 'reporte-1')];
        await pumpView(tester);
        reports.repository
          ..others = []
          ..voteError = const NotFoundException(message: 'Reporte não encontrado.');

        await vote(tester);

        expect(find.text('Reporte não encontrado'), findsOneWidget);
      });
    });

    testWidgets('deve ampliar a foto no toque e fechar', (tester) async {
      reports.repository.mine = [sampleReportWith(id: 'reporte-1')];
      await pumpView(tester);

      await tester.tap(find.bySemanticsLabel('Foto do buraco'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Foto do buraco, ampliada'), findsOneWidget);

      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Foto do buraco, ampliada'), findsNothing);
    });

    testWidgets('deve abrir a edição', (tester) async {
      reports.repository.mine = [sampleReportWith(id: 'reporte-1', canEdit: true)];
      await pumpView(tester);

      await tapVisible(tester, _editButton);

      expect(find.text('Tela da edição'), findsOneWidget);
    });

    group('excluir', () {
      setUp(() => reports.repository.mine = [sampleReportWith(id: 'reporte-1')]);

      testWidgets('deve excluir depois da confirmação e voltar, sem o detalhe na pilha', (
        tester,
      ) async {
        final router = await pumpView(tester);

        await tapVisible(tester, _deleteButton);

        expect(find.text('Excluir o reporte?'), findsOneWidget);
        expect(find.text('Esta ação não pode ser desfeita.'), findsOneWidget);

        await tester.tap(
          find.descendant(of: find.byType(AlertDialog), matching: find.text('Excluir')),
        );
        await tester.pumpAndSettle();

        expect(reports.repository.deleteCalls, ['reporte-1']);
        expect(find.text(screenBelow), findsOneWidget);
        expect(find.text('Reporte excluído.'), findsOneWidget);
        expect(router.canPop(), isFalse, reason: 'O "voltar" não volta para o detalhe.');
      });

      testWidgets('não deve excluir no "Cancelar"', (tester) async {
        await pumpView(tester);

        await tapVisible(tester, _deleteButton);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();

        expect(reports.repository.deleteCalls, isEmpty);
        expect(find.byType(ReportDetailView), findsOneWidget);
      });

      testWidgets('deve avisar sem conexão e continuar no detalhe', (tester) async {
        await pumpView(tester);
        reports.repository.deleteError = const NetworkException();

        await tapVisible(tester, _deleteButton);
        await tester.tap(
          find.descendant(of: find.byType(AlertDialog), matching: find.text('Excluir')),
        );
        await tester.pumpAndSettle();

        expect(find.text(NetworkException.defaultMessage), findsOneWidget);
        expect(find.byType(ReportDetailView), findsOneWidget);
      });
    });

    testWidgets('deve mostrar a mensagem e o "Voltar" no reporte excluído em outro aparelho '
        '(404)', (tester) async {
      await pumpView(tester);

      expect(find.text('Reporte não encontrado'), findsOneWidget);

      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text(screenBelow), findsOneWidget);
    });

    testWidgets('deve mostrar o erro com o "Tentar de novo"', (tester) async {
      reports.repository.mine = [sampleReportWith(id: 'reporte-1')];
      reports.repository.getByIdError = const NetworkException();
      await pumpView(tester);

      expect(find.text('O reporte não carregou'), findsOneWidget);

      reports.repository.getByIdError = null;
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.text('Em validação'), findsOneWidget);
    });

    testWidgets('deve buscar de novo no puxar para atualizar, e avisar quando falha', (
      tester,
    ) async {
      reports.repository.mine = [sampleReportWith(id: 'reporte-1')];
      await pumpView(tester);
      reports.repository.mine = [sampleReportWith(id: 'reporte-1', confirmations: 4)];

      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('4 de 10 confirmações'), findsOneWidget);

      reports.repository.getByIdError = const NetworkException();
      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.textContaining('O reporte não foi atualizado.'), findsOneWidget);
      expect(find.text('4 de 10 confirmações'), findsOneWidget);
    });

    testWidgets('deve aguentar a fonte em 200%', (tester) async {
      tester.usePhoneScreen(textScale: 2);
      reports.repository.mine = [sampleReportWith(id: 'reporte-1', canEdit: true)];

      await pumpView(tester);
      await tester.ensureVisible(_deleteButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('deve passar nas verificações de acessibilidade', (tester) async {
      reports.repository.mine = [sampleReportWith(id: 'reporte-1', canEdit: true)];
      tester.view
        ..physicalSize = const Size(800, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      await tester.pumpApp(
        const ReportDetailView(reportId: 'reporte-1'),
        overrides: [...auth.overrides, ...reports.overrides],
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  });
}
