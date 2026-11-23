import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/location/location_service.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';
import 'package:reportaai_cm/features/reports/domain/models/vote_type.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/report_vote_bar.dart';

import '../../../../support/app_lifecycle.dart';
import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_location_service.dart';
import '../../../../support/fake_report_repository.dart';
import '../../../../support/pump_app.dart';
import '../../../../support/report_fakes.dart';

final Finder _confirmButton = find.widgetWithText(FilledButton, 'Está lá');
final Finder _denyButton = find.widgetWithText(OutlinedButton, 'Não está lá');
final Finder _dialogConfirm = find.descendant(
  of: find.byType(AlertDialog),
  matching: find.text('Confirmar'),
);

void main() {
  group('ReportVoteBar', () {
    late AuthFakes auth;
    late ReportFakes reports;

    final report = othersReport(id: 'reporte-perto');

    setUp(() {
      auth = verifiedAuthFakes();
      reports = ReportFakes()..repository.others = [report];
    });

    Future<void> pumpBar(WidgetTester tester, {Report? shown, bool compact = false}) async {
      await tester.pumpApp(
        Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [ReportVoteBar(report: shown ?? report, compact: compact)],
          ),
        ),
        overrides: [...auth.overrides, ...reports.overrides],
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapAndSettle(WidgetTester tester, Finder target) async {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    /// Toca no "Está lá" e confirma.
    Future<void> confirmVote(WidgetTester tester) async {
      await tapAndSettle(tester, _confirmButton);
      await tapAndSettle(tester, _dialogConfirm);
    }

    testWidgets('deve mostrar o "Está lá", o "Não está lá" e a explicação', (tester) async {
      await pumpBar(tester);

      expect(find.text('O buraco ainda está lá?'), findsOneWidget);
      expect(find.textContaining('a até 500 m'), findsOneWidget);
      expect(_confirmButton, findsOneWidget);
      expect(_denyButton, findsOneWidget);
    });

    testWidgets('deve pedir a confirmação e votar no "Confirmar" (RM29)', (tester) async {
      await pumpBar(tester);

      await tapAndSettle(tester, _confirmButton);

      expect(find.text('Confirmar que o buraco está lá?'), findsOneWidget);
      expect(find.text('O voto não pode ser desfeito.'), findsOneWidget);

      await tapAndSettle(tester, _dialogConfirm);

      final call = reports.repository.voteCalls.single;
      expect(call.vote, VoteType.confirm);
      expect(call.location.accuracyMeters, 8);
      expect(
        find.text('Voto registrado. Obrigado por ajudar a validar o reporte.'),
        findsOneWidget,
      );
    });

    testWidgets('deve pedir a confirmação do "Não está lá" com o texto dele', (tester) async {
      await pumpBar(tester);

      await tapAndSettle(tester, _denyButton);

      expect(find.text('Confirmar que o buraco não está lá?'), findsOneWidget);

      await tapAndSettle(tester, _dialogConfirm);

      expect(reports.repository.voteCalls.single.vote, VoteType.deny);
    });

    testWidgets('não deve votar no "Cancelar"', (tester) async {
      await pumpBar(tester);

      await tapAndSettle(tester, _confirmButton);
      await tapAndSettle(tester, find.text('Cancelar'));

      expect(reports.repository.voteCalls, isEmpty);
      expect(reports.location.positionCalls, 0);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('deve mostrar o carregando durante o voto, com os botões desativados', (
      tester,
    ) async {
      reports.location.positionPending = Completer();
      await pumpBar(tester);

      await tapAndSettle(tester, _confirmButton);
      await tester.tap(_dialogConfirm);
      await tester.pump();
      await tester.pump();

      expect(find.text('Conferindo a sua localização…'), findsOneWidget);
      expect(tester.widget<FilledButton>(_confirmButton).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(_denyButton).onPressed, isNull);
      expect(find.bySemanticsLabel(RegExp('Votando')), findsOneWidget);

      reports.repository.votePending = Completer();
      reports.location.positionPending!.complete();
      await tester.pump();
      await tester.pump();

      expect(find.text('Enviando o voto…'), findsOneWidget);

      reports.repository.votePending!.complete();
      await tester.pumpAndSettle();

      expect(find.text('Enviando o voto…'), findsNothing);
    });

    group('localização', () {
      testWidgets('deve mostrar a localização imprecisa no lugar dos botões, sem votar, e votar '
          'depois do "Atualizar localização"', (tester) async {
        reports.location.position = campoMouraoPositionWith(accuracyMeters: 120);
        await pumpBar(tester);

        await confirmVote(tester);

        expect(find.text('A localização está imprecisa'), findsOneWidget);
        expect(find.textContaining('Para votar, ela precisa ser de até 50 m'), findsOneWidget);
        expect(_confirmButton, findsNothing);
        expect(reports.repository.voteCalls, isEmpty);

        reports.location.position = campoMouraoPosition;
        await tapAndSettle(tester, find.text('Atualizar localização'));

        expect(reports.repository.voteCalls, hasLength(1));
        expect(find.textContaining('Voto registrado.'), findsOneWidget);
      });

      testWidgets('deve recusar a localização simulada', (tester) async {
        reports.location.position = campoMouraoPositionWith(isMocked: true);
        await pumpBar(tester);

        await confirmVote(tester);

        expect(find.text('A localização parece falsa'), findsOneWidget);
        expect(reports.repository.voteCalls, isEmpty);
      });

      testWidgets('deve explicar o porquê antes do pedido da permissão, e votar com ela', (
        tester,
      ) async {
        reports.location.permission = LocationPermissionStatus.denied;
        await pumpBar(tester);

        await confirmVote(tester);

        expect(find.text('Precisamos da sua localização'), findsOneWidget);
        expect(find.textContaining('se você está perto do buraco'), findsOneWidget);
        expect(reports.location.requestPermissionCalls, 0);

        await tapAndSettle(tester, find.text('Permitir a localização'));

        expect(reports.location.requestPermissionCalls, 1);
        expect(reports.repository.voteCalls, hasLength(1));
      });

      testWidgets('deve abrir as configurações com o GPS desligado e votar na volta do app', (
        tester,
      ) async {
        reports.location.serviceEnabled = false;
        await pumpBar(tester);

        await confirmVote(tester);
        expect(find.text('Ligue a localização para votar.'), findsOneWidget);

        await tapAndSettle(tester, find.text('Ativar a localização'));
        expect(reports.location.openLocationSettingsCalls, 1);

        reports.location.serviceEnabled = true;
        tester.leaveAndComeBack();
        await tester.pumpAndSettle();

        expect(reports.repository.voteCalls, hasLength(1));
      });

      testWidgets('deve abrir as configurações do app com a permissão negada para sempre', (
        tester,
      ) async {
        reports.location.permission = LocationPermissionStatus.deniedForever;
        await pumpBar(tester);

        await confirmVote(tester);
        await tapAndSettle(tester, find.text('Abrir as configurações'));

        expect(reports.location.openAppSettingsCalls, 1);
      });

      testWidgets('deve voltar aos botões no "Cancelar o voto"', (tester) async {
        reports.location.serviceEnabled = false;
        await pumpBar(tester);

        await confirmVote(tester);
        await tapAndSettle(tester, find.text('Cancelar o voto'));

        expect(_confirmButton, findsOneWidget);
        expect(reports.repository.voteCalls, isEmpty);
      });
    });

    group('respostas da API', () {
      for (final (description, error, message) in [
        (
          '409 do voto repetido',
          const ConflictException(message: 'Você já votou neste reporte.'),
          'Você já votou neste reporte.',
        ),
        (
          '422 de quem está longe',
          const BusinessRuleException(
            message: 'Você precisa estar a até 500 m do reporte para votar.',
          ),
          'Você precisa estar a até 500 m do reporte para votar.',
        ),
        (
          '422 do reporte fora da validação',
          const BusinessRuleException(message: 'Este reporte não está mais em validação.'),
          'Este reporte não está mais em validação.',
        ),
        ('sem conexão', const NetworkException(), NetworkException.defaultMessage),
      ]) {
        testWidgets('deve mostrar a mensagem do $description', (tester) async {
          reports.repository.voteError = error;
          await pumpBar(tester);

          await confirmVote(tester);

          expect(find.text(message), findsOneWidget);
          expect(find.textContaining('Voto registrado.'), findsNothing);
          expect(_confirmButton, findsOneWidget);
        });
      }
    });

    testWidgets('deve mostrar o voto já dado no lugar dos botões', (tester) async {
      await pumpBar(tester, shown: othersReport(myVote: VoteType.confirm));

      expect(find.text('Você confirmou'), findsOneWidget);
      expect(_confirmButton, findsNothing);

      await pumpBar(tester, shown: othersReport(myVote: VoteType.deny));

      expect(find.text('Você disse que não está lá'), findsOneWidget);
    });

    testWidgets('não deve mostrar nada no próprio reporte e sem o canVote', (tester) async {
      await pumpBar(tester, shown: sampleReportWith(id: 'meu'));

      expect(find.byType(FilledButton), findsNothing);

      await pumpBar(tester, shown: othersReport(status: ReportStatus.confirmed));

      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('O buraco ainda está lá?'), findsNothing);
    });

    testWidgets('deve mostrar o aviso do e-mail no lugar dos botões, sem o e-mail confirmado '
        '(RM20)', (tester) async {
      auth = AuthFakes(signedIn: true);
      await pumpBar(tester);

      expect(find.text('Confirme o seu e-mail'), findsOneWidget);
      expect(find.text('Depois de confirmar o e-mail, volte aqui para votar.'), findsOneWidget);
      expect(_confirmButton, findsNothing);
    });

    testWidgets('deve mostrar só os botões na lista, sem a explicação e sem o aviso do e-mail', (
      tester,
    ) async {
      await pumpBar(tester, compact: true);

      expect(find.text('O buraco ainda está lá?'), findsNothing);
      expect(_confirmButton, findsOneWidget);

      auth = AuthFakes(signedIn: true);
      await pumpBar(tester, compact: true);

      expect(find.text('Confirme o seu e-mail'), findsNothing);
      expect(_confirmButton, findsNothing);
    });

    testWidgets('deve aguentar a fonte em 200%, com a localização parada', (tester) async {
      tester.usePhoneScreen(textScale: 2);
      reports.location.position = campoMouraoPositionWith(accuracyMeters: 120);
      await pumpBar(tester);

      await tapAndSettle(tester, _confirmButton);
      expect(tester.takeException(), isNull, reason: 'A confirmação do voto');
      await tapAndSettle(tester, _dialogConfirm);
      expect(tester.takeException(), isNull, reason: 'O cartão da localização');
      await tester.ensureVisible(find.text('Cancelar o voto'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('deve passar nas verificações de acessibilidade', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpApp(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ReportVoteBar(report: report),
          ),
        ),
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
