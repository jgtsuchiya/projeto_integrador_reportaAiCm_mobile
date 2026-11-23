import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/location/location_service.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';
import 'package:reportaai_cm/features/reports/domain/models/vote_type.dart';
import 'package:reportaai_cm/features/reports/presentation/views/nearby_reports_view.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/nearby_report_item.dart';

import '../../../../support/app_lifecycle.dart';
import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_location_service.dart';
import '../../../../support/fake_report_repository.dart';
import '../../../../support/pump_app.dart';
import '../../../../support/report_fakes.dart';

/// O item da lista com a [description].
Finder _item(String description) =>
    find.ancestor(of: find.text(description), matching: find.byType(NearbyReportItem));

void main() {
  group('NearbyReportsView', () {
    late AuthFakes auth;
    late ReportFakes reports;

    setUp(() {
      auth = verifiedAuthFakes();
      reports = ReportFakes()
        ..repository.nearby = [
          othersReport(id: 'reporte-perto', distanceMeters: 40, description: 'Buraco perto'),
          othersReport(id: 'reporte-longe', distanceMeters: 320, description: 'Buraco longe'),
        ];
    });

    /// Abre a tela por cima de outra, como pela tela inicial, com o detalhe na rota de cima.
    Future<GoRouter> pumpView(WidgetTester tester, {bool settle = true}) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text(screenBelow)),
          ),
          GoRoute(path: '/reportes/perto', builder: (context, state) => const NearbyReportsView()),
          GoRoute(
            path: '/reportes/:id',
            builder: (context, state) =>
                Scaffold(body: Text('Detalhe ${state.pathParameters['id']} a ${state.extra} m')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpRouter(router, overrides: [...auth.overrides, ...reports.overrides]);
      AuthFakes.startAuth(tester.container());
      await tester.pumpAndSettle();
      unawaited(router.push('/reportes/perto'));
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
      }
      return router;
    }

    Future<void> tapAndSettle(WidgetTester tester, Finder target) async {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    testWidgets('deve mostrar a busca da localização', (tester) async {
      reports.location.positionPending = Completer();

      await pumpView(tester, settle: false);
      await tester.pump();

      expect(find.text('Buscando a sua localização'), findsOneWidget);

      reports.location.positionPending!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('deve mostrar o carregando da lista', (tester) async {
      reports.repository.nearbyPending = Completer();

      await pumpView(tester, settle: false);
      await tester.pump();
      await tester.pump();

      expect(find.text('Carregando os reportes perto de você'), findsOneWidget);

      reports.repository.nearbyPending!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('deve listar os reportes do mais perto ao mais longe, com a distância, as '
        'confirmações e o voto (RM28)', (tester) async {
      await pumpView(tester);

      expect(find.text('A 40 m de você'), findsOneWidget);
      expect(find.text('A 320 m de você'), findsOneWidget);
      expect(
        tester.getTopLeft(_item('Buraco perto')).dy,
        lessThan(tester.getTopLeft(_item('Buraco longe')).dy),
      );
      expect(
        find.descendant(of: _item('Buraco perto'), matching: find.text('3 de 10 confirmações')),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Está lá'), findsNWidgets(2));
      expect(find.widgetWithText(OutlinedButton, 'Não está lá'), findsNWidgets(2));
      expect(find.text('O buraco ainda está lá?'), findsNothing, reason: 'Sem a explicação.');
      expect(reports.repository.nearbyCalls.single.radiusMeters, 500);
    });

    testWidgets('não deve mostrar os próprios reportes nem os já confirmados (RM28)', (
      tester,
    ) async {
      reports.repository.nearby = [
        sampleReportWith(id: 'meu', description: 'Meu buraco', distanceMeters: 5),
        othersReport(
          id: 'confirmado',
          description: 'Já confirmado',
          status: ReportStatus.confirmed,
        ),
        othersReport(id: 'reporte-perto', description: 'Buraco perto'),
      ];

      await pumpView(tester);

      expect(find.text('Meu buraco'), findsNothing);
      expect(find.text('Já confirmado'), findsNothing);
      expect(find.text('Buraco perto'), findsOneWidget);
    });

    testWidgets('deve mostrar os já votados no fim, marcados', (tester) async {
      reports.repository.nearby = [
        othersReport(
          id: 'votado',
          distanceMeters: 10,
          description: 'Já votado',
          myVote: VoteType.confirm,
        ),
        othersReport(id: 'reporte-perto', distanceMeters: 40, description: 'Buraco perto'),
      ];

      await pumpView(tester);

      expect(
        tester.getTopLeft(_item('Buraco perto')).dy,
        lessThan(tester.getTopLeft(_item('Já votado')).dy),
      );
      expect(
        find.descendant(of: _item('Já votado'), matching: find.text('Você confirmou')),
        findsOneWidget,
      );
    });

    testWidgets('deve votar e levar o reporte para o fim da lista, sem buscar de novo (RM30)', (
      tester,
    ) async {
      await pumpView(tester);

      await tapAndSettle(
        tester,
        find.descendant(
          of: _item('Buraco perto'),
          matching: find.widgetWithText(FilledButton, 'Está lá'),
        ),
      );
      await tapAndSettle(
        tester,
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Confirmar')),
      );

      expect(reports.repository.voteCalls.single.id, 'reporte-perto');
      expect(
        tester.getTopLeft(_item('Buraco longe')).dy,
        lessThan(tester.getTopLeft(_item('Buraco perto')).dy),
      );
      expect(
        find.descendant(of: _item('Buraco perto'), matching: find.text('Você confirmou')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _item('Buraco perto'), matching: find.text('4 de 10 confirmações')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _item('Buraco perto'), matching: find.text('A 40 m de você')),
        findsOneWidget,
      );
      expect(find.textContaining('Voto registrado.'), findsOneWidget);
      expect(reports.repository.nearbyCalls, hasLength(1));
    });

    testWidgets('deve mostrar o status novo no item do voto que chega a 10', (tester) async {
      reports.repository.nearby = [
        othersReport(
          id: 'reporte-perto',
          distanceMeters: 40,
          description: 'Buraco perto',
          confirmations: 9,
        ),
      ];
      await pumpView(tester);

      await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Está lá'));
      await tapAndSettle(
        tester,
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Confirmar')),
      );

      expect(
        find.descendant(of: _item('Buraco perto'), matching: find.text('Confirmado')),
        findsOneWidget,
      );
    });

    testWidgets('deve abrir o detalhe no toque, com a distância', (tester) async {
      await pumpView(tester);

      await tapAndSettle(tester, find.text('Buraco longe'));

      expect(find.text('Detalhe reporte-longe a 320 m'), findsOneWidget);
    });

    testWidgets('deve mostrar a lista vazia, e buscar de novo no "Atualizar"', (tester) async {
      reports.repository.nearby = [];
      await pumpView(tester);

      expect(find.text('Nenhum reporte em validação perto de você.'), findsOneWidget);

      reports.repository.nearby = [othersReport(description: 'Buraco novo')];
      await tapAndSettle(tester, find.widgetWithText(OutlinedButton, 'Atualizar'));

      expect(find.text('Buraco novo'), findsOneWidget);
      expect(reports.location.positionCalls, 2, reason: 'A localização também é lida de novo.');
    });

    testWidgets('deve buscar de novo no "Atualizar" da barra e no puxar para atualizar', (
      tester,
    ) async {
      await pumpView(tester);
      reports.repository.nearby = [othersReport(description: 'Buraco novo')];

      await tapAndSettle(tester, find.byTooltip('Atualizar'));

      expect(find.text('Buraco novo'), findsOneWidget);

      reports.repository.nearby = [othersReport(description: 'Outro buraco')];
      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Outro buraco'), findsOneWidget);
      expect(reports.repository.nearbyCalls, hasLength(3));
    });

    testWidgets('deve explicar e pedir a permissão da localização, e mostrar a lista com ela', (
      tester,
    ) async {
      reports.location.permission = LocationPermissionStatus.denied;
      await pumpView(tester);

      expect(find.text('Precisamos da sua localização'), findsOneWidget);
      expect(find.textContaining('os buracos reportados perto de você'), findsOneWidget);
      expect(reports.repository.nearbyCalls, isEmpty);

      await tapAndSettle(tester, find.text('Permitir a localização'));

      expect(reports.location.requestPermissionCalls, 1);
      expect(find.text('Buraco perto'), findsOneWidget);
    });

    testWidgets('deve abrir as configurações com a permissão negada para sempre', (tester) async {
      reports.location.permission = LocationPermissionStatus.deniedForever;
      await pumpView(tester);

      await tapAndSettle(tester, find.text('Abrir as configurações'));

      expect(reports.location.openAppSettingsCalls, 1);
    });

    testWidgets('deve pedir para ligar o GPS e buscar a lista na volta do app', (tester) async {
      reports.location.serviceEnabled = false;
      await pumpView(tester);

      expect(find.text('Ligue a localização para ver os reportes perto de você.'), findsOneWidget);

      await tapAndSettle(tester, find.text('Ativar a localização'));
      expect(reports.location.openLocationSettingsCalls, 1);

      reports.location.serviceEnabled = true;
      tester.leaveAndComeBack();
      await tester.pumpAndSettle();

      expect(find.text('Buraco perto'), findsOneWidget);
    });

    testWidgets('deve mostrar a localização imprecisa e buscar de novo no "Atualizar '
        'localização"', (tester) async {
      reports.location.position = campoMouraoPositionWith(accuracyMeters: 120);
      await pumpView(tester);

      expect(find.text('A localização está imprecisa'), findsOneWidget);
      expect(find.textContaining('Para ver os reportes perto'), findsOneWidget);

      reports.location.position = campoMouraoPosition;
      await tapAndSettle(tester, find.text('Atualizar localização'));

      expect(find.text('Buraco perto'), findsOneWidget);
    });

    testWidgets('deve buscar de novo pelo "Atualizar" da barra, sem a lista na tela', (
      tester,
    ) async {
      reports.location.serviceEnabled = false;
      await pumpView(tester);
      reports.location.serviceEnabled = true;

      await tapAndSettle(tester, find.byTooltip('Atualizar'));

      expect(find.text('Buraco perto'), findsOneWidget);
    });

    testWidgets('deve mostrar o erro com o "Tentar de novo"', (tester) async {
      reports.repository.nearbyError = const NetworkException();
      await pumpView(tester);

      expect(find.text('Os reportes não carregaram'), findsOneWidget);
      expect(find.text(NetworkException.defaultMessage), findsOneWidget);

      reports.repository.nearbyError = null;
      await tapAndSettle(tester, find.text('Tentar de novo'));

      expect(find.text('Buraco perto'), findsOneWidget);
    });

    testWidgets('deve manter a lista e avisar quando o "Atualizar" falha', (tester) async {
      await pumpView(tester);
      reports.repository.nearbyError = const ServerException();

      await tapAndSettle(tester, find.byTooltip('Atualizar'));

      expect(find.textContaining('A lista não foi atualizada.'), findsOneWidget);
      expect(find.text('Buraco perto'), findsOneWidget);
    });

    testWidgets('deve mostrar a lista sem o voto e com o aviso do e-mail em cima, sem o e-mail '
        'confirmado (RM20)', (tester) async {
      auth = AuthFakes(signedIn: true);
      await pumpView(tester);

      expect(find.text('Confirme o seu e-mail'), findsOneWidget);
      expect(find.text('Buraco perto'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Está lá'), findsNothing);
    });

    testWidgets('deve aguentar a fonte em 200%', (tester) async {
      tester.usePhoneScreen(textScale: 2);
      await pumpView(tester);

      // A lista só monta os itens à vista: rola até o último.
      await tester.dragUntilVisible(
        find.text('Buraco longe'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('deve passar nas verificações de acessibilidade', (tester) async {
      tester.view
        ..physicalSize = const Size(800, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      await tester.pumpApp(
        const NearbyReportsView(),
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
