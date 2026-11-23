import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/widgets/app_text_field.dart';
import 'package:reportaai_cm/core/widgets/error_view.dart';
import 'package:reportaai_cm/core/widgets/loading_indicator.dart';
import 'package:reportaai_cm/core/widgets/primary_button.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_draft.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_limits.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/edit_report_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/new_report_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_detail_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/report_photo_view.dart';

/// "Editar reporte" (`/reportes/:id/editar`): a descrição e o "Trocar a foto" (RM25). A
/// localização não muda: para mudar o lugar, é preciso excluir e abrir outro. Só o que mudou vai
/// para a API, e sem mudança o "Salvar" fica desativado. Ao sair com alterações não salvas, a tela
/// pergunta se quer descartá-las.
///
/// O reporte vem do detalhe, que fica embaixo desta tela (também num deep link).
class EditReportView extends ConsumerStatefulWidget {
  const new({required this.reportId, super.key});

  final String reportId;

  @override
  ConsumerState<EditReportView> createState() => _EditReportViewState();
}

class _EditReportViewState extends ConsumerState<EditReportView> {
  final _description = TextEditingController();
  var _isFilled = false;

  EditReportViewModel get _viewModel =>
      ref.read(editReportViewModelProvider(widget.reportId).notifier);

  @override
  void initState() {
    super.initState();
    // O campo começa com a descrição do reporte, que pode chegar depois (num deep link).
    ref.listenManual(reportDetailViewModelProvider(widget.reportId), (previous, next) {
      final report = next.report;
      if (_isFilled || report == null) return;

      _isFilled = true;
      _description.text = report.description ?? '';
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit(Report report) async {
    final outcome = await _viewModel.submit(report, _description.text);
    if (outcome == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(outcome.message)));
    context.pop();
  }

  /// O "voltar" com alterações não salvas: pergunta antes de descartá-las.
  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar as alterações?'),
        content: const Text('O que você mudou no reporte não foi salvo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar editando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(reportDetailViewModelProvider(widget.reportId));
    final report = detail.report;
    final editing = ref.watch(editReportViewModelProvider(widget.reportId));

    final Widget body;
    if (report == null && (detail.isNotFound || detail.loadError != null)) {
      body = ErrorView(
        title: 'O reporte não carregou',
        message: detail.isNotFound
            ? 'Ele pode ter sido excluído.'
            : detail.loadError ?? 'Tente de novo em instantes.',
        secondaryAction: OutlinedButton(
          onPressed: () => context.pop(),
          child: const Text('Voltar'),
        ),
      );
    } else if (report == null) {
      body = const LoadingIndicator(message: 'Carregando o reporte');
    } else if (!report.canEdit) {
      body = ErrorView(
        title: 'Este reporte não pode mais ser editado',
        message: 'Só dá para editar o reporte em validação, antes de alguém votar.',
        secondaryAction: OutlinedButton(
          onPressed: () => context.pop(),
          child: const Text('Voltar'),
        ),
      );
    } else {
      body = _form(report, editing);
    }

    return ListenableBuilder(
      listenable: _description,
      builder: (context, child) {
        final hasChanges =
            report != null && !_viewModel.changesFrom(report, _description.text).isEmpty;

        return PopScope(
          canPop: !hasChanges || editing.isSubmitting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_confirmDiscard());
          },
          child: child!,
        );
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Editar reporte')),
        body: SafeArea(child: body),
      ),
    );
  }

  Widget _form(Report report, EditReportState editing) {
    final theme = Theme.of(context);
    final message = editing.message;
    final newPhoto = editing.newPhoto;

    final Widget photo;
    if (newPhoto != null) {
      photo = Image.memory(
        newPhoto.photo,
        fit: BoxFit.cover,
        semanticLabel: 'Foto nova do buraco, ainda não salva',
      );
    } else if (editing.isChangingPhoto) {
      photo = ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: LoadingIndicator(
          message: editing.photoStatus == PhotoStatus.capturing
              ? 'A câmera está aberta.'
              : 'Preparando a foto…',
        ),
      );
    } else {
      photo = ReportPhotoView(
        reportId: report.id,
        photo: report.photo,
        size: ReportPhotoSize.full,
        semanticLabel: 'Foto atual do buraco',
      );
    }
    final aspectRatio = switch (newPhoto) {
      final photo? => photo.width / photo.height,
      null => report.photo.width / report.photo.height,
    };

    return ScrollableCenter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: AspectRatio(aspectRatio: aspectRatio, child: photo),
            ),
          ),
          if (editing.photoError case final error?) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: editing.isSubmitting || editing.isChangingPhoto
                  ? null
                  : () => unawaited(_viewModel.takePhoto()),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Trocar a foto'),
            ),
          ),
          const SizedBox(height: 8),
          Card.outlined(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'A localização não muda. Para mudar o lugar, exclua este reporte e abra '
                      'outro.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          AppTextField(
            label: 'Descrição (opcional)',
            controller: _description,
            errorText: editing.descriptionError,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            textCapitalization: TextCapitalization.sentences,
            minLines: 2,
            maxLines: 6,
            maxLength: ReportLimits.descriptionMaxLength,
            enabled: !editing.isSubmitting,
            onChanged: (_) => _viewModel.descriptionChanged(),
            scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 160),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 24),
          ListenableBuilder(
            listenable: _description,
            builder: (context, _) => PrimaryButton(
              label: 'Salvar',
              isLoading: editing.isSubmitting,
              // Sem mudança, ou com a foto nova ainda sendo tratada, nada a salvar.
              onPressed:
                  editing.isChangingPhoto ||
                      _viewModel.changesFrom(report, _description.text).isEmpty
                  ? null
                  : () => unawaited(_submit(report)),
            ),
          ),
        ],
      ),
    );
  }
}
