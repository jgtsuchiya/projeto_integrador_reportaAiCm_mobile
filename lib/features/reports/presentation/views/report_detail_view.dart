import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/routes.dart';
import 'package:reportaai_cm/core/utils/date_formatters.dart';
import 'package:reportaai_cm/core/widgets/error_view.dart';
import 'package:reportaai_cm/core/widgets/loading_indicator.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_draft.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_detail_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/report_location_card.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/report_photo_view.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/report_status_label.dart';

/// O detalhe do reporte (`/reportes/:id`): a foto (o toque amplia), o status e o progresso (RM26),
/// a descrição, as datas e a precisão da localização. "Editar" e "Excluir" aparecem só quando a
/// API permite (RM25). No reporte de outro cidadão, a distância, quando a tela anterior a sabe, e
/// nenhum dado do autor (RM27).
///
/// Puxar para atualizar busca o reporte de novo.
class ReportDetailView extends ConsumerStatefulWidget {
  const new({required this.reportId, this.distanceMeters, super.key});

  final String reportId;

  /// A distância até o reporte, da busca dos reportes perto, como o aviso do reporte repetido.
  final int? distanceMeters;

  @override
  ConsumerState<ReportDetailView> createState() => _ReportDetailViewState();
}

class _ReportDetailViewState extends ConsumerState<ReportDetailView> {
  ReportDetailViewModel get _viewModel =>
      ref.read(reportDetailViewModelProvider(widget.reportId).notifier);

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir o reporte?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final error = await _viewModel.delete();
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text(ReportDetailViewModel.deletedMessage)));
    // O detalhe sai da pilha: o "voltar" da tela de baixo não volta para ele.
    context.pop();
  }

  /// A foto ampliada, por cima da tela, com o zoom dos dedos.
  Future<void> _enlargePhoto(Report report) => showDialog<void>(
    context: context,
    builder: (context) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: ReportPhotoView(
                  reportId: report.id,
                  photo: report.photo,
                  size: ReportPhotoSize.full,
                  fit: BoxFit.contain,
                  semanticLabel: 'Foto do buraco, ampliada',
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Fechar',
                icon: const Icon(Icons.close),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportDetailViewModelProvider(widget.reportId));
    final report = state.report;
    final loadError = state.loadError;

    final Widget body;
    if (state.isNotFound) {
      body = ErrorView(
        title: 'Reporte não encontrado',
        message: 'Ele pode ter sido excluído.',
        secondaryAction: OutlinedButton(
          onPressed: () => context.pop(),
          child: const Text('Voltar'),
        ),
      );
    } else if (report == null && loadError != null) {
      body = ErrorView(
        title: 'O reporte não carregou',
        message: loadError,
        onRetry: () => unawaited(_viewModel.load()),
      );
    } else if (report == null) {
      body = const LoadingIndicator(message: 'Carregando o reporte');
    } else {
      body = RefreshIndicator(
        onRefresh: _viewModel.load,
        child: ListView(
          // O puxar para atualizar funciona também quando tudo cabe na tela, sem rolar.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: ScrollableCenter.maxContentWidth),
                child: _ReportDetails(
                  report: report,
                  distanceMeters: widget.distanceMeters,
                  loadError: loadError,
                  isDeleting: state.isDeleting,
                  onEnlargePhoto: () => unawaited(_enlargePhoto(report)),
                  onEdit: () => unawaited(context.push(AppRoutes.reportEdit(report.id))),
                  onDelete: () => unawaited(_delete()),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reporte')),
      body: SafeArea(child: body),
    );
  }
}

class _ReportDetails extends StatelessWidget {
  const new({
    required this.report,
    required this.distanceMeters,
    required this.loadError,
    required this.isDeleting,
    required this.onEnlargePhoto,
    required this.onEdit,
    required this.onDelete,
  });

  final Report report;
  final int? distanceMeters;
  final String? loadError;
  final bool isDeleting;
  final VoidCallback onEnlargePhoto;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final secondary = theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant);
    final description = report.description;
    final statusDetail = reportStatusDetail(report);
    final statusChangedAt = report.statusChangedAt;
    final distance = report.distanceMeters ?? distanceMeters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loadError != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              'O reporte não foi atualizado. $loadError',
              style: theme.textTheme.bodyLarge?.copyWith(color: colors.error),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Semantics(
          button: true,
          hint: 'Toque para ampliar',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onEnlargePhoto,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: AspectRatio(
                  aspectRatio: report.photo.width / report.photo.height,
                  child: ReportPhotoView(
                    reportId: report.id,
                    photo: report.photo,
                    size: ReportPhotoSize.full,
                    semanticLabel: 'Foto do buraco',
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ReportStatusLabel(status: report.status),
        ),
        if (statusDetail != null) ...[
          const SizedBox(height: 8),
          Text(statusDetail, style: theme.textTheme.bodyLarge),
        ],
        if (report.status == ReportStatus.pending) ...[
          const SizedBox(height: 12),
          ReportConfirmationProgress(votes: report.votes),
        ],
        const SizedBox(height: 24),
        _Section(
          title: 'Descrição',
          child: Text(
            description ?? 'Sem descrição.',
            style: description == null ? secondary : theme.textTheme.bodyLarge,
          ),
        ),
        _Section(
          title: 'Datas',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aberto em ${formatDateTime(report.createdAt.toLocal())}',
                style: theme.textTheme.bodyLarge,
              ),
              if (statusChangedAt != null)
                Text(
                  'Status mudou em ${formatDateTime(statusChangedAt.toLocal())}',
                  style: theme.textTheme.bodyLarge,
                ),
            ],
          ),
        ),
        _Section(
          title: 'Localização',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!report.isMine && distance != null)
                Text('A $distance m de você', style: theme.textTheme.bodyLarge),
              Text(accuracyText(report.location.accuracyMeters), style: theme.textTheme.bodyLarge),
              if (report.isMine)
                Text('A localização não muda depois da abertura.', style: secondary),
            ],
          ),
        ),
        if (report.canEdit || report.canDelete) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (report.canEdit)
                OutlinedButton.icon(
                  onPressed: isDeleting ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
              if (report.canDelete)
                OutlinedButton.icon(
                  onPressed: isDeleting ? null : onDelete,
                  style: OutlinedButton.styleFrom(foregroundColor: colors.error),
                  icon: isDeleting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: 'Excluindo',
                          ),
                        )
                      : const Icon(Icons.delete_outline),
                  label: const Text('Excluir'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Um bloco do detalhe: o título pequeno e o conteúdo, lidos juntos pelo leitor de tela.
class _Section extends StatelessWidget {
  const new({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      ),
    );
  }
}
