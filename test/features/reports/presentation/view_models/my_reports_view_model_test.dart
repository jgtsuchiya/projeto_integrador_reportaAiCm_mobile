import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/my_reports_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_refresh.dart';

import '../../../../support/fake_report_repository.dart';
import '../../../../support/report_fakes.dart';

void main() {
  group('MyReportsViewModel', () {
    late ReportFakes reports;
    late ProviderContainer container;

    setUp(() {
      reports = ReportFakes();
      container = ProviderContainer.test(overrides: reports.overrides, retry: noAutomaticRetry);
    });

    /// Abre a tela e espera a primeira página.
    Future<ProviderSubscription<MyReportsState>> open() async {
      final screen = container.listen(myReportsViewModelProvider, (_, _) {});
      await pumpEventQueue();
      return screen;
    }

    MyReportsViewModel sut() => container.read(myReportsViewModelProvider.notifier);
    MyReportsState state() => container.read(myReportsViewModelProvider);

    test('deve começar carregando e trazer a primeira página, com 20 itens', () async {
      reports.repository.mine = myReports(25);
      container.listen(myReportsViewModelProvider, (_, _) {});

      expect(state().isLoading, isTrue);
      expect(state().items, isNull);

      await pumpEventQueue();

      expect(state().items, hasLength(20));
      expect(state().total, 25);
      expect(state().hasMore, isTrue);
      expect(reports.repository.listMineCalls.single, (page: 1, pageSize: 20, status: null));
    });

    test('deve trazer a lista vazia', () async {
      await open();

      expect(state().items, isEmpty);
      expect(state().hasMore, isFalse);
    });

    test('deve juntar a página seguinte no fim, sem repetir itens', () async {
      reports.repository.mine = myReports(25);
      await open();
      // Um reporte novo no começo empurra a lista: o 20º vem de novo na página 2.
      reports.repository.mine = [sampleReportWith(id: 'mais-novo'), ...myReports(25)];

      await sut().loadMore();

      // O mais novo entra no próximo puxar para atualizar.
      final ids = state().items!.map((report) => report.id).toList();
      expect(ids, hasLength(25));
      expect(ids.toSet(), hasLength(25));
      expect(state().total, 26);
      expect(state().page, 2);
      expect(state().hasMore, isFalse);
    });

    test('não deve buscar mais sem outra página, nem duas vezes ao mesmo tempo', () async {
      reports.repository.mine = myReports(5);
      await open();

      await sut().loadMore();

      expect(reports.repository.listMineCalls, hasLength(1));

      reports.repository.mine = myReports(25);
      await sut().reload();
      reports.repository.listMinePending = Completer();
      unawaited(sut().loadMore());
      unawaited(sut().loadMore());
      await pumpEventQueue();

      expect(state().isLoadingMore, isTrue);
      expect(reports.repository.listMineCalls, hasLength(3));
      reports.repository.listMinePending!.complete();
    });

    test('deve mostrar o erro da primeira página, e o "Tentar de novo" busca de novo', () async {
      reports.repository.listMineError = const NetworkException();
      await open();

      expect(state().loadError, NetworkException.defaultMessage);
      expect(state().items, isNull);

      reports.repository.listMineError = null;
      await sut().reload();

      expect(state().loadError, isNull);
      expect(state().items, isEmpty);
    });

    test('deve manter o que já carregou quando a página seguinte falha', () async {
      reports.repository.mine = myReports(25);
      await open();
      reports.repository.listMineError = const ServerException();

      await sut().loadMore();

      expect(state().items, hasLength(20));
      expect(state().loadMoreError, ServerException.defaultMessage);

      reports.repository.listMineError = null;
      await sut().loadMore();

      expect(state().items, hasLength(25));
      expect(state().loadMoreError, isNull);
    });

    test('deve manter a lista quando o puxar para atualizar falha', () async {
      reports.repository.mine = myReports(3);
      await open();
      reports.repository.listMineError = const NetworkException();

      await sut().reload();

      expect(state().items, hasLength(3));
      expect(state().loadError, NetworkException.defaultMessage);
    });

    test('deve filtrar por status, e voltar a "Todos"', () async {
      reports.repository.mine = [
        sampleReportWith(id: 'a', status: ReportStatus.pending),
        sampleReportWith(id: 'b', status: ReportStatus.confirmed),
        sampleReportWith(id: 'c', status: ReportStatus.rejected),
      ];
      await open();

      await sut().selectFilter(ReportFilter.confirmed);

      expect(state().filter, ReportFilter.confirmed);
      expect(state().items!.map((report) => report.id), ['b']);
      expect(reports.repository.listMineCalls.last.status, ReportStatus.confirmed);

      await sut().selectFilter(ReportFilter.all);

      expect(state().items, hasLength(3));
      expect(reports.repository.listMineCalls.last.status, isNull);
    });

    test('não deve buscar de novo o filtro que já está escolhido', () async {
      await open();

      await sut().selectFilter(ReportFilter.all);

      expect(reports.repository.listMineCalls, hasLength(1));
    });

    test('deve descartar a página do filtro anterior que chega depois', () async {
      reports.repository.mine = [
        sampleReportWith(id: 'a', status: ReportStatus.pending),
        sampleReportWith(id: 'b', status: ReportStatus.confirmed),
      ];
      reports.repository.listMinePending = Completer();
      container.listen(myReportsViewModelProvider, (_, _) {});
      await pumpEventQueue();

      final filtered = sut().selectFilter(ReportFilter.confirmed);
      reports.repository.listMinePending!.complete();
      await filtered;
      await pumpEventQueue();

      expect(state().filter, ReportFilter.confirmed);
      expect(state().items!.map((report) => report.id), ['b']);
    });

    test('deve buscar de novo quando um reporte muda (ref.invalidate)', () async {
      await open();

      container.read(reportRefreshProvider).reportsChanged();
      await pumpEventQueue();

      expect(reports.repository.listMineCalls, hasLength(2));
    });

    test('não deve mudar o estado depois que a tela fecha', () async {
      reports.repository.listMinePending = Completer();
      final screen = container.listen(myReportsViewModelProvider, (_, _) {});
      await pumpEventQueue();

      screen.close();
      await pumpEventQueue();
      reports.repository.listMinePending!.complete();
      await pumpEventQueue();

      expect(reports.repository.listMineCalls, hasLength(1));
    });

    test('deve descrever o estado e comparar pelos campos', () async {
      reports.repository.mine = myReports(2);
      await open();

      expect(state().toString(), contains('items: 2'));
      expect(state(), state());
      expect(state().hashCode, state().hashCode);
    });
  });
}
