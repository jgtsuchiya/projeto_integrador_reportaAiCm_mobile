import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/core/location/location_service.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';
import 'package:reportaai_cm/features/reports/domain/models/vote_type.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/nearby_reports_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_detail_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_location.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_vote_view_model.dart';

import '../../../../support/fake_location_service.dart';
import '../../../../support/fake_report_repository.dart';
import '../../../../support/report_fakes.dart';

void main() {
  group('ReportVoteViewModel', () {
    late ReportFakes reports;
    late ProviderContainer container;

    const id = 'reporte-perto';
    final provider = reportVoteViewModelProvider(id);

    setUp(() {
      reports = ReportFakes()..repository.others = [othersReport(id: id)];
      container = ProviderContainer.test(overrides: reports.overrides, retry: noAutomaticRetry)
        ..listen(provider, (_, _) {});
    });

    ReportVoteViewModel sut() => container.read(provider.notifier);
    ReportVoteState state() => container.read(provider);

    test('deve começar sem voto em andamento', () {
      expect(state(), const ReportVoteState());
      expect(state().step.isBusy, isFalse);
    });

    test('deve ler a localização atual, votar e devolver o reporte da API (RM29)', () async {
      final report = await sut().vote(VoteType.confirm);

      final call = reports.repository.voteCalls.single;
      expect(call.id, id);
      expect(call.vote, VoteType.confirm);
      expect(call.location.latitude, campoMouraoPosition.latitude);
      expect(call.location.accuracyMeters, 8);
      expect(report?.votes.confirmations, 4);
      expect(report?.votes.mine, VoteType.confirm);
      expect(reports.location.positionCalls, 1);
      expect(state(), const ReportVoteState());
    });

    test('não deve guardar a localização do voto no estado (RM29)', () async {
      final steps = <ReportVoteState>[];
      container.listen(provider, (_, next) => steps.add(next));

      await sut().vote(VoteType.deny);

      expect(steps.map((step) => step.step), [VoteStep.locating, VoteStep.sending, VoteStep.idle]);
      expect(steps.map((step) => step.location), everyElement(isNull));
    });

    test('deve atualizar o detalhe aberto com o reporte da resposta, sem buscar de novo '
        '(RM30)', () async {
      final detail = reportDetailViewModelProvider(id);
      container.listen(detail, (_, _) {});
      await pumpEventQueue();

      await sut().vote(VoteType.confirm);

      expect(container.read(detail).report?.votes.mine, VoteType.confirm);
      expect(container.read(detail).report?.votes.confirmations, 4);
      expect(reports.repository.getByIdCalls, hasLength(1));
    });

    test('deve atualizar a lista dos reportes perto aberta, com o votado no fim (RM30)', () async {
      reports.repository.nearby = [
        othersReport(id: id, distanceMeters: 40),
        othersReport(id: 'mais-longe', distanceMeters: 200),
      ];
      container.listen(nearbyReportsViewModelProvider, (_, _) {});
      await pumpEventQueue();

      await sut().vote(VoteType.confirm);

      final items = container.read(nearbyReportsViewModelProvider).items!;
      expect(items.map((report) => report.id), ['mais-longe', id]);
      expect(items.last.distanceMeters, 40, reason: 'A distância continua a da busca.');
      expect(reports.repository.nearbyCalls, hasLength(1));
    });

    test('deve mostrar o status novo do voto que chega a 10 (RM30)', () async {
      reports.repository.others = [othersReport(id: id, confirmations: 9)];

      final report = await sut().vote(VoteType.confirm);

      expect(report?.status, ReportStatus.confirmed);
      expect(
        ReportVoteViewModel.votedMessageFor(report!),
        'Voto registrado. Com ele, o reporte foi confirmado.',
      );
    });

    test('deve escrever a mensagem do voto pelo status da resposta', () {
      expect(
        ReportVoteViewModel.votedMessageFor(othersReport(status: ReportStatus.rejected)),
        'Voto registrado. Com ele, o reporte foi descartado.',
      );
      expect(
        ReportVoteViewModel.votedMessageFor(othersReport()),
        'Voto registrado. Obrigado por ajudar a validar o reporte.',
      );
    });

    group('localização', () {
      for (final (description, setUpLocation, status) in [
        (
          'imprecisa',
          (FakeLocationService location) =>
              location.position = campoMouraoPositionWith(accuracyMeters: 120),
          LocationStatus.inaccurate,
        ),
        (
          'simulada',
          (FakeLocationService location) =>
              location.position = campoMouraoPositionWith(isMocked: true),
          LocationStatus.mocked,
        ),
        (
          'sem a permissão pedida',
          (FakeLocationService location) => location.permission = LocationPermissionStatus.denied,
          LocationStatus.permissionNeeded,
        ),
        (
          'com o GPS desligado',
          (FakeLocationService location) => location.serviceEnabled = false,
          LocationStatus.serviceDisabled,
        ),
        (
          'que não chega a tempo',
          (FakeLocationService location) =>
              location.positionError = const LocationTimeoutException(),
          LocationStatus.failed,
        ),
      ]) {
        test('deve parar o voto com a localização $description, sem chamar a API (RM29)', () async {
          setUpLocation(reports.location);

          final report = await sut().vote(VoteType.confirm);

          expect(report, isNull);
          expect(state().step, VoteStep.blocked);
          expect(state().vote, VoteType.confirm);
          expect(state().location?.status, status);
          expect(reports.repository.voteCalls, isEmpty);
        });
      }

      test('deve enviar o voto que esperava depois do "Atualizar localização"', () async {
        reports.location.position = campoMouraoPositionWith(accuracyMeters: 120);
        await sut().vote(VoteType.deny);
        reports.location.position = campoMouraoPosition;

        final report = await sut().refreshLocation();

        expect(report, isNotNull);
        expect(reports.repository.voteCalls.single.vote, VoteType.deny);
        expect(state(), const ReportVoteState());
      });

      test('deve pedir a permissão e enviar o voto, com ela aceita', () async {
        reports.location.permission = LocationPermissionStatus.denied;
        await sut().vote(VoteType.confirm);

        final report = await sut().requestLocationPermission();

        expect(reports.location.requestPermissionCalls, 1);
        expect(report, isNotNull);
        expect(reports.repository.voteCalls, hasLength(1));
      });

      test('deve continuar parado com a permissão negada de novo', () async {
        reports.location
          ..permission = LocationPermissionStatus.denied
          ..permissionAfterRequest = LocationPermissionStatus.denied;
        await sut().vote(VoteType.confirm);

        await sut().requestLocationPermission();

        expect(state().location?.status, LocationStatus.permissionDenied);
        expect(reports.repository.voteCalls, isEmpty);
      });

      test('deve abrir as configurações e ler de novo na volta do app', () async {
        reports.location.serviceEnabled = false;
        await sut().vote(VoteType.confirm);

        await sut().openLocationSettings();
        await sut().openAppSettings();
        reports.location.serviceEnabled = true;
        final report = await sut().onResume();

        expect(reports.location.openLocationSettingsCalls, 1);
        expect(reports.location.openAppSettingsCalls, 1);
        expect(report, isNotNull);
      });

      test(
        'não deve ler a localização na volta do app sem o voto parado pelas configurações',
        () async {
          reports.location.position = campoMouraoPositionWith(accuracyMeters: 120);

          expect(await sut().onResume(), isNull);

          await sut().vote(VoteType.confirm);
          expect(await sut().onResume(), isNull);
          expect(reports.location.positionCalls, 1);
        },
      );

      test('deve cancelar o voto parado', () async {
        reports.location.serviceEnabled = false;
        await sut().vote(VoteType.confirm);

        sut().cancel();

        expect(state(), const ReportVoteState());
        expect(await sut().refreshLocation(), isNull);
      });

      test('não deve fazer nada no "Cancelar" e nas ações sem o voto parado', () async {
        sut().cancel();

        expect(await sut().refreshLocation(), isNull);
        expect(await sut().requestLocationPermission(), isNull);
        expect(state(), const ReportVoteState());
      });
    });

    group('respostas da API', () {
      test(
        'deve mostrar a mensagem do 409 e buscar o reporte, para mostrar o voto já dado',
        () async {
          final detail = reportDetailViewModelProvider(id);
          container.listen(detail, (_, _) {});
          await pumpEventQueue();
          reports.repository
            ..voteError = const ConflictException(message: 'Você já votou neste reporte.')
            ..others = [othersReport(id: id, myVote: VoteType.confirm)];

          final report = await sut().vote(VoteType.confirm);
          await pumpEventQueue();

          expect(report, isNull);
          expect(state().message, 'Você já votou neste reporte.');
          expect(container.read(detail).report?.votes.mine, VoteType.confirm);
        },
      );

      test('deve mostrar a mensagem do 422 de quem está longe (RN38)', () async {
        const message = 'Você precisa estar a até 500 m do reporte para votar.';
        reports.repository.voteError = const BusinessRuleException(message: message);

        await sut().vote(VoteType.confirm);
        await pumpEventQueue();

        expect(state(), const ReportVoteState(message: message));
        expect(reports.repository.getByIdCalls, [id]);
      });

      test('deve tirar o reporte das telas no 404', () async {
        reports.repository
          ..nearby = [othersReport(id: id), othersReport(id: 'outro', distanceMeters: 90)]
          ..voteError = const NotFoundException(message: 'Reporte não encontrado.');
        final detail = reportDetailViewModelProvider(id);
        container
          ..listen(detail, (_, _) {})
          ..listen(nearbyReportsViewModelProvider, (_, _) {});
        await pumpEventQueue();
        reports.repository
          ..others = []
          ..nearby = [];

        await sut().vote(VoteType.confirm);
        await pumpEventQueue();

        expect(state().message, 'Reporte não encontrado.');
        expect(container.read(detail).isNotFound, isTrue);
        expect(container.read(nearbyReportsViewModelProvider).items?.map((report) => report.id), [
          'outro',
        ]);
      });

      test('deve tirar o reporte quando a busca depois do 422 dá 404', () async {
        reports.repository.voteError = const BusinessRuleException(
          message: 'Este reporte não está mais em validação.',
        );
        final detail = reportDetailViewModelProvider(id);
        container.listen(detail, (_, _) {});
        await pumpEventQueue();
        reports.repository.others = [];

        await sut().vote(VoteType.confirm);
        await pumpEventQueue();

        expect(container.read(detail).isNotFound, isTrue);
      });

      test('deve manter a tela quando a busca depois do 409 falha', () async {
        final detail = reportDetailViewModelProvider(id);
        container.listen(detail, (_, _) {});
        await pumpEventQueue();
        final before = container.read(detail).report;
        reports.repository
          ..voteError = const ConflictException(message: 'Você já votou neste reporte.')
          ..getByIdError = const NetworkException();

        await sut().vote(VoteType.confirm);
        await pumpEventQueue();

        expect(container.read(detail).report, before);
        expect(state().message, 'Você já votou neste reporte.');
      });

      test('deve mostrar a mensagem sem conexão, e votar de novo depois', () async {
        reports.repository.voteError = const NetworkException();

        await sut().vote(VoteType.confirm);

        expect(state().message, NetworkException.defaultMessage);

        reports.repository.voteError = null;
        expect(await sut().vote(VoteType.confirm), isNotNull);
        expect(state().message, isNull);
      });
    });

    test('não deve votar duas vezes ao mesmo tempo', () async {
      reports.repository.votePending = Completer();

      unawaited(sut().vote(VoteType.confirm));
      await pumpEventQueue();

      expect(state().step, VoteStep.sending);
      expect(await sut().vote(VoteType.deny), isNull);
      expect(reports.repository.voteCalls, hasLength(1));
      reports.repository.votePending!.complete();
    });

    test('deve descartar o resultado depois de a tela fechar', () async {
      reports.repository.votePending = Completer();
      final subscription = container.listen(provider, (_, _) {});

      final voting = sut().vote(VoteType.confirm);
      await pumpEventQueue();
      subscription.close();
      container.invalidate(provider);
      reports.repository.votePending!.complete();

      expect(await voting, isNotNull);
    });

    test('deve descrever o estado sem a posição e comparar pelos campos', () {
      const blocked = ReportVoteState(
        step: VoteStep.blocked,
        vote: VoteType.confirm,
        location: LocationReading(LocationStatus.inaccurate),
      );

      expect(blocked, isNot(const ReportVoteState()));
      expect(blocked.hashCode, isNot(const ReportVoteState().hashCode));
      expect(blocked.toString(), contains('blocked'));
      expect(blocked.toString(), contains('inaccurate'));
    });
  });
}
