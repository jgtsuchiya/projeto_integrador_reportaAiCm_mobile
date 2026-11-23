import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/my_reports_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_detail_view_model.dart';

import '../../../../support/fake_report_repository.dart';
import '../../../../support/report_fakes.dart';

void main() {
  group('ReportDetailViewModel', () {
    late ReportFakes reports;
    late ProviderContainer container;

    final report = sampleReportWith(id: 'reporte-1', canEdit: true);
    final provider = reportDetailViewModelProvider('reporte-1');

    setUp(() {
      reports = ReportFakes()..repository.mine = [report];
      container = ProviderContainer.test(overrides: reports.overrides, retry: noAutomaticRetry);
    });

    Future<void> open() async {
      container.listen(provider, (_, _) {});
      await pumpEventQueue();
    }

    ReportDetailViewModel sut() => container.read(provider.notifier);
    ReportDetailState state() => container.read(provider);

    test('deve começar carregando e trazer o reporte', () async {
      container.listen(provider, (_, _) {});

      expect(state().isLoading, isTrue);

      await pumpEventQueue();

      expect(state(), ReportDetailState(report: report));
      expect(reports.repository.getByIdCalls, ['reporte-1']);
    });

    test('deve marcar o reporte que não existe mais (404)', () async {
      reports.repository.mine = [];

      await open();

      expect(state().isNotFound, isTrue);
      expect(state().report, isNull);
    });

    test('deve mostrar o erro e buscar de novo no "Tentar de novo"', () async {
      reports.repository.getByIdError = const NetworkException();
      await open();

      expect(state().loadError, NetworkException.defaultMessage);

      reports.repository.getByIdError = null;
      await sut().load();

      expect(state(), ReportDetailState(report: report));
    });

    test('deve manter o reporte quando o puxar para atualizar falha', () async {
      await open();
      reports.repository.getByIdError = const ServerException();

      await sut().load();

      expect(state().report, report);
      expect(state().loadError, ServerException.defaultMessage);
    });

    test('deve trocar o reporte pelo da API sem buscar de novo', () async {
      await open();
      final updated = sampleReportWith(id: 'reporte-1', description: 'Nova');

      sut().replace(updated);

      expect(state().report, updated);
      expect(reports.repository.getByIdCalls, hasLength(1));
    });

    group('delete', () {
      test('deve excluir e atualizar a lista', () async {
        container.listen(myReportsViewModelProvider, (_, _) {});
        await open();

        final error = await sut().delete();
        await pumpEventQueue();

        expect(error, isNull);
        expect(reports.repository.deleteCalls, ['reporte-1']);
        expect(reports.repository.mine, isEmpty);
        expect(reports.repository.listMineCalls, hasLength(2));
      });

      test('deve tratar o reporte já excluído (404) como excluído', () async {
        await open();
        reports.repository.deleteError = const NotFoundException();

        expect(await sut().delete(), isNull);
      });

      test('deve devolver a mensagem sem conexão e manter o reporte', () async {
        await open();
        reports.repository.deleteError = const NetworkException();

        expect(await sut().delete(), NetworkException.defaultMessage);
        expect(state(), ReportDetailState(report: report));
      });

      test('não deve excluir duas vezes', () async {
        await open();
        reports.repository.deletePending = Completer();

        unawaited(sut().delete());
        await pumpEventQueue();

        expect(state().isDeleting, isTrue);
        expect(await sut().delete(), isNull);
        expect(reports.repository.deleteCalls, hasLength(1));
        reports.repository.deletePending!.complete();
      });
    });

    test('deve descrever o estado e comparar pelos campos', () async {
      await open();

      expect(state().toString(), contains('isNotFound: false'));
      expect(state().hashCode, ReportDetailState(report: report).hashCode);
    });
  });
}
