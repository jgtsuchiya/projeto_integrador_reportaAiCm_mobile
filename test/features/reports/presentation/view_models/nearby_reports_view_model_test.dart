import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/core/location/location_service.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/reports/domain/models/geo_location.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';
import 'package:reportaai_cm/features/reports/domain/models/vote_type.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/nearby_reports_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_location.dart';

import '../../../../support/fake_location_service.dart';
import '../../../../support/fake_report_repository.dart';
import '../../../../support/report_fakes.dart';

void main() {
  group('reportsToValidate', () {
    test('deve deixar só os em validação de outros cidadãos, com os já votados no fim (RM28)', () {
      final reports = reportsToValidate([
        othersReport(id: 'votado-perto', distanceMeters: 10, myVote: VoteType.confirm),
        othersReport(id: 'perto', distanceMeters: 20),
        sampleReportWith(id: 'meu', distanceMeters: 25),
        othersReport(id: 'confirmado', distanceMeters: 30, status: ReportStatus.confirmed),
        othersReport(id: 'longe', distanceMeters: 300),
        othersReport(id: 'votado-longe', distanceMeters: 400, myVote: VoteType.deny),
      ]);

      expect(reports.map((report) => report.id), [
        'perto',
        'longe',
        'votado-perto',
        'votado-longe',
      ]);
    });

    test('deve manter a ordem da API com a mesma distância', () {
      final reports = arrangeNearbyReports([
        othersReport(id: 'b', distanceMeters: 50),
        othersReport(id: 'a', distanceMeters: 50),
        othersReport(id: 'sem-distancia', distanceMeters: null),
      ]);

      expect(reports.map((report) => report.id), ['sem-distancia', 'b', 'a']);
    });
  });

  group('NearbyReportsViewModel', () {
    late ReportFakes reports;
    late ProviderContainer container;

    setUp(() {
      reports = ReportFakes()
        ..repository.nearby = [
          othersReport(id: 'perto', distanceMeters: 40),
          othersReport(id: 'longe', distanceMeters: 320),
        ];
      container = ProviderContainer.test(overrides: reports.overrides, retry: noAutomaticRetry);
    });

    Future<void> open() async {
      container.listen(nearbyReportsViewModelProvider, (_, _) {});
      await pumpEventQueue();
    }

    NearbyReportsViewModel sut() => container.read(nearbyReportsViewModelProvider.notifier);
    NearbyReportsState state() => container.read(nearbyReportsViewModelProvider);

    test('deve começar buscando a localização e trazer os reportes a até 500 m (RM28)', () async {
      container.listen(nearbyReportsViewModelProvider, (_, _) {});

      expect(state().isLoading, isTrue);
      expect(state().location.status, LocationStatus.capturing);

      await pumpEventQueue();

      expect(state().items?.map((report) => report.id), ['perto', 'longe']);
      expect(state().isLoading, isFalse);
      expect(state().location, const LocationReading(LocationStatus.ready));
      final call = reports.repository.nearbyCalls.single;
      expect(call.radiusMeters, 500);
      expect(
        call.point,
        GeoPoint(latitude: campoMouraoPosition.latitude, longitude: campoMouraoPosition.longitude),
      );
    });

    test('deve guardar a localização pronta sem a posição', () async {
      await open();

      expect(state().location.position, isNull);
    });

    for (final (description, setUpLocation, status) in [
      (
        'imprecisa',
        (FakeLocationService location) =>
            location.position = campoMouraoPositionWith(accuracyMeters: 80),
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
        'negada para sempre',
        (FakeLocationService location) =>
            location.permission = LocationPermissionStatus.deniedForever,
        LocationStatus.permissionDeniedForever,
      ),
      (
        'com o GPS desligado',
        (FakeLocationService location) => location.serviceEnabled = false,
        LocationStatus.serviceDisabled,
      ),
    ]) {
      test('não deve buscar a lista com a localização $description', () async {
        setUpLocation(reports.location);

        await open();

        expect(state().location.status, status);
        expect(state().items, isNull);
        expect(reports.repository.nearbyCalls, isEmpty);
      });
    }

    test('deve pedir a permissão, depois da explicação, e buscar a lista', () async {
      reports.location.permission = LocationPermissionStatus.denied;
      await open();

      await sut().requestLocationPermission();

      expect(reports.location.requestPermissionCalls, 1);
      expect(state().items, hasLength(2));
    });

    test('deve abrir as configurações e buscar de novo na volta do app', () async {
      reports.location.serviceEnabled = false;
      await open();

      await sut().openLocationSettings();
      await sut().openAppSettings();
      reports.location.serviceEnabled = true;
      await sut().onResume();

      expect(reports.location.openLocationSettingsCalls, 1);
      expect(reports.location.openAppSettingsCalls, 1);
      expect(state().items, hasLength(2));
    });

    test('não deve buscar de novo na volta do app com a lista na tela', () async {
      await open();

      await sut().onResume();

      expect(reports.repository.nearbyCalls, hasLength(1));
    });

    test('deve mostrar o erro da lista, e mantê-la quando o "Atualizar" falha', () async {
      reports.repository.nearbyError = const NetworkException();
      await open();

      expect(state().items, isNull);
      expect(state().loadError, NetworkException.defaultMessage);

      reports.repository.nearbyError = null;
      await sut().load();
      reports.repository.nearbyError = const ServerException();
      await sut().load();

      expect(state().items, hasLength(2));
      expect(state().loadError, ServerException.defaultMessage);
    });

    test('deve manter a lista durante o "Atualizar" e trazer a nova', () async {
      await open();
      reports.location.positionPending = Completer();
      reports.repository.nearby = [othersReport(id: 'novo', distanceMeters: 15)];

      final loading = sut().load();
      await pumpEventQueue();

      expect(state().isLoading, isTrue);
      expect(state().items, hasLength(2));

      reports.location.positionPending!.complete();
      await loading;

      expect(state().items?.map((report) => report.id), ['novo']);
    });

    test('deve tirar a lista quando a localização deixa de servir', () async {
      await open();
      reports.location.position = campoMouraoPositionWith(accuracyMeters: 90);

      await sut().load();

      expect(state().items, isNull);
      expect(state().location.status, LocationStatus.inaccurate);
    });

    test('deve descartar a busca atropelada pelo "Atualizar"', () async {
      await open();
      reports.repository
        ..nearbyPending = Completer()
        ..nearby = [othersReport(id: 'antigo', distanceMeters: 10)];
      final first = sut().load();
      await pumpEventQueue();
      final firstPending = reports.repository.nearbyPending!;
      reports.repository
        ..nearbyPending = null
        ..nearby = [othersReport(id: 'novo', distanceMeters: 15)];
      await sut().load();
      firstPending.complete();
      await first;

      expect(state().items?.map((report) => report.id), ['novo']);
    });

    test(
      'deve trocar o reporte votado, com a distância da busca, e levá-lo para o fim (RM30)',
      () async {
        await open();

        sut().replaceReport(
          othersReport(
            id: 'perto',
            distanceMeters: null,
            myVote: VoteType.confirm,
            confirmations: 4,
          ),
        );

        final items = state().items!;
        expect(items.map((report) => report.id), ['longe', 'perto']);
        expect(items.last.distanceMeters, 40);
        expect(items.last.votes.confirmations, 4);
        expect(reports.repository.nearbyCalls, hasLength(1));
      },
    );

    test('deve manter o reporte votado que mudou de status, marcado', () async {
      await open();

      sut().replaceReport(
        othersReport(id: 'perto', status: ReportStatus.confirmed, myVote: VoteType.confirm),
      );

      expect(state().items?.last.status, ReportStatus.confirmed);
    });

    test('deve ignorar o reporte que não está na lista, e a lista ainda não carregada', () async {
      container.listen(nearbyReportsViewModelProvider, (_, _) {});
      sut()
        ..replaceReport(othersReport(id: 'perto'))
        ..removeReport('perto');

      expect(state().items, isNull);

      await pumpEventQueue();
      final before = state();
      sut().replaceReport(othersReport(id: 'outro'));

      expect(state(), before);
    });

    test('deve tirar o reporte que não existe mais', () async {
      await open();

      sut().removeReport('perto');

      expect(state().items?.map((report) => report.id), ['longe']);
    });

    test('deve descrever o estado e comparar pelos campos', () async {
      await open();

      expect(state().toString(), contains('items: 2'));
      expect(state(), NearbyReportsState(location: state().location, items: state().items));
      expect(
        state().hashCode,
        NearbyReportsState(location: state().location, items: state().items).hashCode,
      );
    });
  });
}
