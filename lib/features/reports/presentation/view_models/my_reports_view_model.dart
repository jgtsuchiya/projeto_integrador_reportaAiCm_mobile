import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';
import 'package:reportaai_cm/features/reports/reports_providers.dart';

/// Estado da tela "Meus reportes": a lista paginada, o filtro e os erros.
final NotifierProvider<MyReportsViewModel, MyReportsState> myReportsViewModelProvider =
    NotifierProvider.autoDispose(MyReportsViewModel.new);

/// O filtro por status da lista, com o rótulo do chip.
enum ReportFilter {
  all('Todos', null),
  pending('Em validação', ReportStatus.pending),
  confirmed('Confirmados', ReportStatus.confirmed),
  rejected('Descartados', ReportStatus.rejected);

  new(this.label, this.status);

  final String label;

  /// O status pedido à API. `null` em "Todos".
  final ReportStatus? status;
}

@immutable
final class MyReportsState {
  const new({
    this.filter = ReportFilter.all,
    this.items,
    this.total = 0,
    this.page = 0,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.loadError,
    this.loadMoreError,
  });

  final ReportFilter filter;

  /// Os reportes das páginas já carregadas, do mais novo ao mais antigo. `null` até a primeira
  /// página chegar.
  final List<Report>? items;

  /// O total de reportes do filtro, em todas as páginas.
  final int total;

  /// A última página carregada, a partir de 1.
  final int page;

  /// Se há uma página depois da [page], pela conta da API. Não sai do tamanho da lista: um reporte
  /// que já estava nela não se repete, e ela pode ficar menor que o total.
  final bool hasMore;

  /// A primeira página está carregando: na abertura, no filtro, no "Tentar de novo" e no puxar
  /// para atualizar.
  final bool isLoading;

  /// A página seguinte está carregando, no fim da lista.
  final bool isLoadingMore;

  /// A mensagem da primeira página que falhou. Com uma lista já na tela, ela continua.
  final String? loadError;

  /// A mensagem da página seguinte que falhou: o aviso fica no fim da lista, sem perder o que já
  /// carregou.
  final String? loadMoreError;

  @override
  bool operator ==(Object other) =>
      other is MyReportsState &&
      other.filter == filter &&
      _sameItems(other.items, items) &&
      other.total == total &&
      other.page == page &&
      other.hasMore == hasMore &&
      other.isLoading == isLoading &&
      other.isLoadingMore == isLoadingMore &&
      other.loadError == loadError &&
      other.loadMoreError == loadMoreError;

  @override
  int get hashCode => Object.hash(
    filter,
    items == null ? null : Object.hashAll(items!),
    total,
    page,
    hasMore,
    isLoading,
    isLoadingMore,
    loadError,
    loadMoreError,
  );

  @override
  String toString() =>
      'MyReportsState(filter: ${filter.name}, items: ${items?.length}, total: $total, '
      'page: $page, hasMore: $hasMore, isLoading: $isLoading, isLoadingMore: $isLoadingMore, loadError: $loadError, '
      'loadMoreError: $loadMoreError)';
}

/// Lista os reportes do cidadão (`GET /api/reports/mine`), 20 por página, com a rolagem infinita,
/// o puxar para atualizar e o filtro por status.
final class MyReportsViewModel extends Notifier<MyReportsState> {
  /// Conta as buscas da primeira página: o resultado de uma busca atropelada (o filtro trocado no
  /// meio) é descartado.
  var _run = 0;

  @override
  MyReportsState build() {
    unawaited(Future.microtask(reload));
    return const MyReportsState(isLoading: true);
  }

  /// Busca a primeira página de novo: na abertura, no "Tentar de novo" e no puxar para atualizar.
  /// A lista que já está na tela continua durante a busca e se ela falhar.
  Future<void> reload() async {
    // A tela pode ter fechado antes da primeira busca começar.
    if (!ref.mounted) return;

    final run = ++_run;
    final filter = state.filter;
    state = _copy(isLoading: true, loadError: null, loadMoreError: null);

    try {
      final page = await ref.read(reportRepositoryProvider).listMine(status: filter.status);
      if (!ref.mounted || run != _run) return;

      state = MyReportsState(
        filter: filter,
        items: List.unmodifiable(page.items),
        total: page.total,
        page: page.page,
        hasMore: page.hasMore,
      );
    } on Object catch (error) {
      if (!ref.mounted || run != _run) return;

      state = _copy(isLoading: false, loadError: ApiException.messageOf(error));
    }
  }

  /// Troca o filtro: a lista do filtro anterior sai, e a primeira página do novo é buscada.
  Future<void> selectFilter(ReportFilter filter) async {
    if (filter == state.filter) return;

    state = MyReportsState(filter: filter, isLoading: true);
    await reload();
  }

  /// A página seguinte, no fim da lista. Sem mais páginas, ou com uma busca em andamento, não faz
  /// nada.
  Future<void> loadMore() async {
    final current = state;
    if (!current.hasMore || current.isLoading || current.isLoadingMore) return;

    final run = _run;
    state = _copy(isLoadingMore: true, loadMoreError: null);

    try {
      final page = await ref
          .read(reportRepositoryProvider)
          .listMine(page: current.page + 1, status: current.filter.status);
      if (!ref.mounted || run != _run) return;

      // Um reporte novo no começo empurra os outros: o que já está na lista não se repete.
      final known = {for (final report in current.items!) report.id};
      state = _copy(
        items: List.unmodifiable([
          ...current.items!,
          ...page.items.where((report) => !known.contains(report.id)),
        ]),
        total: page.total,
        page: page.page,
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
    } on Object catch (error) {
      if (!ref.mounted || run != _run) return;

      state = _copy(isLoadingMore: false, loadMoreError: ApiException.messageOf(error));
    }
  }

  /// O estado de agora com os campos passados trocados. Os erros passados como `null` saem.
  MyReportsState _copy({
    List<Report>? items,
    int? total,
    int? page,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    Object? loadError = _keep,
    Object? loadMoreError = _keep,
  }) => MyReportsState(
    filter: state.filter,
    items: items ?? state.items,
    total: total ?? state.total,
    page: page ?? state.page,
    hasMore: hasMore ?? state.hasMore,
    isLoading: isLoading ?? state.isLoading,
    isLoadingMore: isLoadingMore ?? state.isLoadingMore,
    loadError: identical(loadError, _keep) ? state.loadError : loadError as String?,
    loadMoreError: identical(loadMoreError, _keep) ? state.loadMoreError : loadMoreError as String?,
  );
}

/// Marca o campo que o `_copy` mantém como está.
const _keep = Object();

bool _sameItems(List<Report>? a, List<Report>? b) =>
    identical(a, b) || (a != null && b != null && listEquals(a, b));
