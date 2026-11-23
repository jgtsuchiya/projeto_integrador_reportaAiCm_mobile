import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/my_reports_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_detail_view_model.dart';

/// Atualiza as telas dos reportes depois de criar, editar ou excluir um. Os ViewModels o leem antes
/// da chamada à API: a atualização acontece mesmo que a tela que chamou feche no meio.
final reportRefreshProvider = Provider<ReportRefresh>(ReportRefresh.new);

/// Invalida os providers das listas e do detalhe (`ref.invalidate`): a tela aberta busca de novo,
/// e a fechada não faz nada. Não guarda estado.
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
}
