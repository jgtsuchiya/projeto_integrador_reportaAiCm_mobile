import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/my_reports_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/nearby_reports_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_detail_view_model.dart';

/// Atualiza as telas dos reportes depois de criar, editar, excluir ou votar. Os ViewModels o leem
/// antes da chamada à API: a atualização acontece mesmo que a tela que chamou feche no meio.
final reportRefreshProvider = Provider<ReportRefresh>(ReportRefresh.new);

/// Invalida os providers das listas e do detalhe (`ref.invalidate`), ou troca o reporte neles pelo
/// da API: a tela aberta busca de novo ou mostra o reporte novo, e a fechada não faz nada. Não
/// guarda estado.
final class ReportRefresh {
  const new(this._ref);

  final Ref _ref;

  /// Um reporte foi criado, editado ou excluído: "Meus reportes" busca a lista de novo.
  void reportsChanged() => _ref.invalidate(myReportsViewModelProvider);

  /// O reporte [reportId] mudou: a lista e o detalhe dele buscam de novo.
  void reportChanged(String reportId) {
    reportsChanged();
    _ref.invalidate(reportDetailViewModelProvider(reportId));
  }

  /// O reporte mudou fora da tela dele, como no voto (RM30): o detalhe e os "Reportes perto de
  /// você", se estiverem abertos, trocam o reporte pelo [report] da API, sem buscar de novo.
  ///
  /// "Meus reportes" não muda: o voto é sempre no reporte de outro cidadão.
  void reportUpdated(Report report) {
    final detail = reportDetailViewModelProvider(report.id);
    if (_ref.exists(detail)) _ref.read(detail.notifier).replace(report);
    if (_ref.exists(nearbyReportsViewModelProvider)) {
      _ref.read(nearbyReportsViewModelProvider.notifier).replaceReport(report);
    }
  }

  /// O reporte [reportId] não existe mais para o cidadão (404), como o excluído pelo autor no meio
  /// do voto: o detalhe aberto busca de novo e mostra "Reporte não encontrado", e os "Reportes
  /// perto de você" o tiram da lista.
  void reportRemoved(String reportId) {
    final detail = reportDetailViewModelProvider(reportId);
    if (_ref.exists(detail)) unawaited(_ref.read(detail.notifier).load());
    if (_ref.exists(nearbyReportsViewModelProvider)) {
      _ref.read(nearbyReportsViewModelProvider.notifier).removeReport(reportId);
    }
  }
}
