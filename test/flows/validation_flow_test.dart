import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/routes.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/home/presentation/views/home_view.dart';
import 'package:reportaai_cm/features/reports/domain/models/vote_type.dart';
import 'package:reportaai_cm/features/reports/presentation/views/nearby_reports_view.dart';
import 'package:reportaai_cm/features/reports/presentation/views/new_report_view.dart';
import 'package:reportaai_cm/features/reports/presentation/views/report_detail_view.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/nearby_report_item.dart';

import '../support/app_flow.dart';
import '../support/auth_fakes.dart';
import '../support/fake_location_service.dart';
import '../support/fake_profile_repository.dart';
import '../support/fake_report_repository.dart';
import '../support/pump_app.dart';
import '../support/report_fakes.dart';

final Finder _confirmButton = find.widgetWithText(FilledButton, 'Está lá');
final Finder _dialogConfirm = find.descendant(
  of: find.byType(AlertDialog),
  matching: find.text('Confirmar'),
);

/// O item da lista dos reportes perto com a [description].
Finder _item(String description) =>
    find.ancestor(of: find.text(description), matching: find.byType(NearbyReportItem));

/// Os fluxos da validação dos reportes de ponta a ponta, com o app inteiro: as rotas, as telas, o
/// `AuthController` e os ViewModels de verdade, e só a sessão, a API e o GPS trocados pelos fakes.
/// Os detalhes de cada tela ficam nos testes dela.
void main() {
  group('Fluxo da validação dos reportes', () {
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

    /// Abre o app com o Client dentro e, da tela inicial, os "Reportes perto de você".
    Future<List<String>> openNearby(WidgetTester tester) async {
      final history = RouteHistory();
      await tester.pumpWholeApp(
        overrides: [...auth.overrides, ...reports.overrides],
        observers: [history],
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeView), findsOneWidget);

      await _tapAndSettle(tester, find.text('Reportes perto de você'));
      expect(find.byType(NearbyReportsView), findsOneWidget);
      return history.routes;
    }

    testWidgets('deve confirmar pela lista e marcar o reporte, que vai para o fim (RM28 a RM30)', (
      tester,
    ) async {
      final routes = await openNearby(tester);

      await _tapAndSettle(
        tester,
        find.descendant(of: _item('Buraco perto'), matching: _confirmButton),
      );
      expect(find.text('Confirmar que o buraco está lá?'), findsOneWidget);
      expect(find.text('O voto não pode ser desfeito.'), findsOneWidget);
      await _tapAndSettle(tester, _dialogConfirm);

      final vote = reports.repository.voteCalls.single;
      expect((vote.id, vote.vote), ('reporte-perto', VoteType.confirm));
      expect(vote.location.accuracyMeters, 8);
      expect(
        find.descendant(of: _item('Buraco perto'), matching: find.text('Você confirmou')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(_item('Buraco longe')).dy,
        lessThan(tester.getTopLeft(_item('Buraco perto')).dy),
      );
      expect(reports.repository.nearbyCalls, hasLength(1), reason: 'Sem buscar a lista de novo.');

      // O detalhe aberto pela lista mostra o voto e a distância.
      await _tapAndSettle(tester, find.text('Buraco perto'));
      expect(find.byType(ReportDetailView), findsOneWidget);
      expect(find.text('Você confirmou'), findsOneWidget);
      expect(find.text('4 de 10 confirmações'), findsOneWidget);
      expect(find.text('A 40 m de você'), findsOneWidget);
      expect(routes, [
        AppRoutes.splash,
        AppRoutes.home,
        AppRoutes.nearbyReports,
        AppRoutes.reportDetail('reporte-perto'),
      ]);
    });

    testWidgets('deve mostrar "Confirmado" no detalhe e na lista com o voto que chega a 10 '
        '(RM30)', (tester) async {
      reports.repository.nearby = [
        othersReport(
          id: 'reporte-perto',
          distanceMeters: 40,
          description: 'Buraco perto',
          confirmations: 9,
        ),
      ];
      await openNearby(tester);

      await _tapAndSettle(tester, find.text('Buraco perto'));
      await _tapAndSettle(tester, _confirmButton);
      await _tapAndSettle(tester, _dialogConfirm);

      expect(find.text('Confirmado'), findsOneWidget);
      expect(find.text('Voto registrado. Com ele, o reporte foi confirmado.'), findsOneWidget);
      expect(reports.repository.getByIdCalls, hasLength(1), reason: 'Sem recarregar a tela.');

      await _tapAndSettle(tester, find.byType(BackButton));

      expect(find.byType(NearbyReportsView), findsOneWidget);
      expect(
        find.descendant(of: _item('Buraco perto'), matching: find.text('Confirmado')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _item('Buraco perto'), matching: find.text('Você confirmou')),
        findsOneWidget,
      );
    });

    testWidgets('deve mostrar a mensagem da API no voto longe demais (RN38)', (tester) async {
      reports.repository.voteError = const BusinessRuleException(
        message: 'Você precisa estar a até 500 m do reporte para votar.',
      );
      await openNearby(tester);

      await _tapAndSettle(
        tester,
        find.descendant(of: _item('Buraco longe'), matching: _confirmButton),
      );
      await _tapAndSettle(tester, _dialogConfirm);

      expect(
        find.descendant(
          of: _item('Buraco longe'),
          matching: find.text('Você precisa estar a até 500 m do reporte para votar.'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Voto registrado.'), findsNothing);
    });

    testWidgets('deve votar depois do "Atualizar localização", com a localização imprecisa na '
        'hora do voto (RM29)', (tester) async {
      await openNearby(tester);
      reports.location.position = campoMouraoPositionWith(accuracyMeters: 90);

      await _tapAndSettle(
        tester,
        find.descendant(
          of: _item('Buraco perto'),
          matching: find.widgetWithText(OutlinedButton, 'Não está lá'),
        ),
      );
      await _tapAndSettle(tester, _dialogConfirm);

      expect(find.text('A localização está imprecisa'), findsOneWidget);
      expect(reports.repository.voteCalls, isEmpty);

      reports.location.position = campoMouraoPosition;
      await _tapAndSettle(tester, find.text('Atualizar localização'));

      expect(reports.repository.voteCalls.single.vote, VoteType.deny);
      expect(find.text('Você disse que não está lá'), findsOneWidget);
    });

    testWidgets('deve mostrar o aviso com o reenvio sem o e-mail confirmado, e liberar o voto '
        'depois da confirmação (RM20)', (tester) async {
      auth = AuthFakes(signedIn: true);
      await openNearby(tester);

      expect(find.text('Confirme o seu e-mail'), findsOneWidget);
      expect(find.text('Buraco perto'), findsOneWidget);
      expect(_confirmButton, findsNothing);

      await _tapAndSettle(tester, find.text('Buraco perto'));

      expect(find.text('Reenviar e-mail'), findsOneWidget);
      expect(_confirmButton, findsNothing);

      auth.profile.result = clientProfileWith(emailVerifiedAt: emailVerifiedAt);
      await tester.container().read(authControllerProvider.notifier).refreshProfile();
      await tester.pumpAndSettle();

      expect(_confirmButton, findsOneWidget);
    });

    testWidgets('deve confirmar o reporte já aberto pelo "Ver o reporte" do "Novo reporte" '
        '(RM23 e RM29)', (tester) async {
      reports.repository.nearby = [othersReport()];
      await tester.pumpWholeApp(overrides: [...auth.overrides, ...reports.overrides]);
      await tester.pumpAndSettle();

      await _tapAndSettle(tester, find.widgetWithText(FilledButton, 'Novo reporte'));
      await _tapAndSettle(tester, find.text('Ver o reporte'));
      await _tapAndSettle(tester, _confirmButton);
      await _tapAndSettle(tester, _dialogConfirm);

      expect(find.text('Você confirmou'), findsOneWidget);
      expect(reports.repository.createCalls, isEmpty);

      // De volta ao formulário, o aviso do reporte repetido continua: o cidadão decide.
      await _tapAndSettle(tester, find.byType(BackButton));
      expect(find.byType(NewReportView), findsOneWidget);
      expect(find.text('Já existe um reporte a 12 m daqui'), findsOneWidget);
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
