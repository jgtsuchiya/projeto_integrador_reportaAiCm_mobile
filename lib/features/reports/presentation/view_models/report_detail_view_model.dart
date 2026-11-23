import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_refresh.dart';
import 'package:reportaai_cm/features/reports/reports_providers.dart';

/// Estado do detalhe de um reporte, pelo id dele.
final NotifierProviderFamily<ReportDetailViewModel, ReportDetailState, String>
reportDetailViewModelProvider = NotifierProvider.autoDispose
    .family<ReportDetailViewModel, ReportDetailState, String>(ReportDetailViewModel.new);

@immutable
final class ReportDetailState {
  const new({
    this.report,
    this.isLoading = false,
    this.loadError,
    this.isNotFound = false,
    this.isDeleting = false,
  });

  /// O reporte. `null` até a primeira busca chegar.
  final Report? report;

  final bool isLoading;

  /// A mensagem da última busca que falhou. Com o reporte já na tela, ele continua.
  final String? loadError;

  /// O reporte não existe mais, ou o cidadão não o vê (404): excluído em outro aparelho, ou
  /// descartado, de outro cidadão (RN35).
  final bool isNotFound;

  final bool isDeleting;

  @override
  bool operator ==(Object other) =>
      other is ReportDetailState &&
      other.report == report &&
      other.isLoading == isLoading &&
      other.loadError == loadError &&
      other.isNotFound == isNotFound &&
      other.isDeleting == isDeleting;

  @override
  int get hashCode => Object.hash(report, isLoading, loadError, isNotFound, isDeleting);

  @override
  String toString() =>
      'ReportDetailState(report: $report, isLoading: $isLoading, loadError: $loadError, '
      'isNotFound: $isNotFound, isDeleting: $isDeleting)';
}

/// O detalhe do reporte (`GET /api/reports/:id`), o puxar para atualizar e a exclusão (RM25).
final class ReportDetailViewModel extends Notifier<ReportDetailState> {
  new(this.reportId);

  static const deletedMessage = 'Reporte excluído.';

  final String reportId;

  @override
  ReportDetailState build() {
    unawaited(Future.microtask(load));
    return const ReportDetailState(isLoading: true);
  }

  /// Busca o reporte: na abertura, no "Tentar de novo" e no puxar para atualizar. O que já está na
  /// tela continua durante a busca e se ela falhar.
  Future<void> load() async {
    if (!ref.mounted) return;

    state = ReportDetailState(report: state.report, isLoading: true);

    try {
      final report = await ref.read(reportRepositoryProvider).getById(reportId);
      if (ref.mounted) state = ReportDetailState(report: report);
    } on NotFoundException {
      if (ref.mounted) state = const ReportDetailState(isNotFound: true);
    } on Object catch (error) {
      if (ref.mounted) {
        state = ReportDetailState(report: state.report, loadError: ApiException.messageOf(error));
      }
    }
  }

  /// Troca o reporte da tela pelo que a API devolveu, como o da edição: a tela mostra a versão
  /// nova sem buscar de novo.
  void replace(Report report) => state = ReportDetailState(report: report);

  /// Exclui o reporte, depois da confirmação da tela. Devolve `null` quando excluiu, ou a
  /// mensagem do erro para a tela mostrar. O reporte que já tinha sido excluído (404) conta como
  /// excluído.
  Future<String?> delete() async {
    if (state.isDeleting) return null;

    state = ReportDetailState(report: state.report, isDeleting: true);
    // Lido antes da chamada: a lista é atualizada mesmo que a tela feche no meio.
    final refresh = ref.read(reportRefreshProvider);

    try {
      await ref.read(reportRepositoryProvider).delete(reportId);
    } on NotFoundException {
      // Já excluído, em outro aparelho: o resultado é o mesmo.
    } on Object catch (error) {
      if (ref.mounted) state = ReportDetailState(report: state.report);
      return ApiException.messageOf(error);
    }

    refresh.reportsChanged();
    return null;
  }
}
