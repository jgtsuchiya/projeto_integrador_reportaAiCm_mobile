import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/routes.dart';
import 'package:reportaai_cm/app/theme/app_theme.dart';
import 'package:reportaai_cm/core/widgets/app_text_field.dart';
import 'package:reportaai_cm/core/widgets/primary_button.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/widgets/email_verification_notice.dart';
import 'package:reportaai_cm/features/reports/domain/models/prepared_photo.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_draft.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_limits.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/new_report_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/report_location_card.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/report_photo_view.dart';

/// "Novo reporte" (`/reportes/novo`): a foto tirada na hora, a localização com a precisão, o aviso
/// do reporte já aberto ali perto, a descrição e o "Enviar" (RM20 a RM24).
///
/// A câmera abre sozinha. Sem o e-mail confirmado, a tela mostra o aviso com o reenvio no lugar do
/// formulário (RM20). Ao sair com a foto tirada e sem enviar, a tela pergunta se quer descartar.
class NewReportView extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<NewReportView> createState() => _NewReportViewState();
}

class _NewReportViewState extends ConsumerState<NewReportView> {
  final _description = TextEditingController();
  late final AppLifecycleListener _lifecycle;

  NewReportViewModel get _viewModel => ref.read(newReportViewModelProvider.notifier);

  @override
  void initState() {
    super.initState();
    // Na volta das configurações do aparelho, a localização liberada é lida de novo.
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_viewModel.onResume()));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final report = await _viewModel.submit(_description.text);
    if (report == null || !mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(NewReportViewModel.sentMessageFor(report))));
    // O detalhe toma o lugar da tela: o "voltar" não volta para o formulário já enviado.
    context.pushReplacement(AppRoutes.reportDetail(report.id));
  }

  /// O "voltar" com a foto tirada e sem enviar: pergunta antes de descartar.
  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar o reporte?'),
        content: const Text('A foto e a localização ainda não foram enviadas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar o reporte'),
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
    // Depois do "Sair" ou do fim da sessão, a tela ainda aparece durante a troca para o login.
    final profile = switch (ref.watch(authControllerProvider)) {
      AuthAuthenticated(:final profile) => profile,
      _ => null,
    };
    final state = ref.watch(newReportViewModelProvider);

    final Widget body;
    if (profile == null) {
      body = const SizedBox.shrink();
    } else if (profile.emailVerifiedAt == null) {
      body = const ScrollableCenter(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmailVerificationNotice(),
            SizedBox(height: 16),
            Text(
              'Depois de confirmar o e-mail, volte aqui para abrir o reporte.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      body = _form(state);
    }

    return PopScope(
      canPop: !state.hasUnsentPhoto,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmDiscard());
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Novo reporte')),
        body: SafeArea(child: body),
      ),
    );
  }

  Widget _form(NewReportState state) {
    final theme = Theme.of(context);
    final message = state.message;
    final duplicate = state.duplicate;

    return ScrollableCenter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PhotoSection(
            status: state.photoStatus,
            photo: state.photo,
            error: state.photoError,
            onTakePhoto: state.isSubmitting ? null : () => unawaited(_viewModel.takePhoto()),
          ),
          const SizedBox(height: 16),
          ReportLocationCard(
            reading: state.location,
            onRefresh: () => unawaited(_viewModel.refreshLocation()),
            onRequestPermission: () => unawaited(_viewModel.requestLocationPermission()),
            onOpenAppSettings: () => unawaited(_viewModel.openAppSettings()),
            onOpenLocationSettings: () => unawaited(_viewModel.openLocationSettings()),
          ),
          if (state.isCheckingNearby) ...[
            const SizedBox(height: 16),
            Text(
              'Conferindo se o buraco já foi reportado…',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (duplicate != null) ...[
            const SizedBox(height: 16),
            _DuplicateWarning(
              report: duplicate,
              onOpen: () => unawaited(
                context.push(AppRoutes.reportDetail(duplicate.id), extra: duplicate.distanceMeters),
              ),
              onDismiss: _viewModel.dismissDuplicate,
            ),
          ],
          const SizedBox(height: 24),
          AppTextField(
            label: 'Descrição (opcional)',
            controller: _description,
            errorText: state.descriptionError,
            helperText: 'Ex.: na faixa da direita, perto do semáforo',
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            textCapitalization: TextCapitalization.sentences,
            minLines: 2,
            maxLines: 6,
            maxLength: ReportLimits.descriptionMaxLength,
            enabled: !state.isSubmitting,
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
          PrimaryButton(
            label: state.canRetry ? 'Tentar de novo' : 'Enviar',
            isLoading: state.isSubmitting,
            onPressed: state.canSubmit ? () => unawaited(_submit()) : null,
          ),
        ],
      ),
    );
  }
}

/// A foto do reporte em cada passo: a câmera aberta, o tratamento, a foto pronta ou o erro.
class _PhotoSection extends StatelessWidget {
  const new({
    required this.status,
    required this.photo,
    required this.error,
    required this.onTakePhoto,
  });

  final PhotoStatus status;
  final PreparedPhoto? photo;
  final String? error;
  final VoidCallback? onTakePhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = this.photo;

    if (status == PhotoStatus.ready && photo != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: AspectRatio(
                aspectRatio: photo.width / photo.height,
                child: Image.memory(
                  photo.photo,
                  fit: BoxFit.cover,
                  semanticLabel: 'Foto do buraco que você tirou',
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: onTakePhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Tirar outra'),
            ),
          ),
        ],
      );
    }

    final (Widget leading, String text, String? action) = switch (status) {
      PhotoStatus.capturing => (const CircularProgressIndicator(), 'A câmera está aberta.', null),
      PhotoStatus.processing => (const CircularProgressIndicator(), 'Preparando a foto…', null),
      PhotoStatus.failed => (
        Icon(Icons.no_photography_outlined, size: 40, color: theme.colorScheme.error),
        error ?? 'Não foi possível usar esta foto. Tire outra.',
        'Tirar outra',
      ),
      PhotoStatus.empty || PhotoStatus.ready => (
        Icon(Icons.photo_camera_outlined, size: 40, color: theme.colorScheme.primary),
        'Tire uma foto do buraco. A localização do aparelho é lida junto.',
        'Tirar a foto',
      ),
    };

    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            leading,
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(text, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onTakePhoto,
                style: AppTheme.tonalButtonStyle,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(action),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// O aviso do reporte já aberto ali perto (RM23), com a miniatura dele, o "Ver o reporte" e o
/// "É outro buraco".
class _DuplicateWarning extends StatelessWidget {
  const new({required this.report, required this.onOpen, required this.onDismiss});

  final Report report;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final distance = report.distanceMeters ?? 0;
    final title = distance < 1
        ? 'Já existe um reporte neste lugar'
        : 'Já existe um reporte a $distance m daqui';

    return Card(
      margin: EdgeInsets.zero,
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: MergeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox.square(
                        dimension: 72,
                        child: ReportPhotoView(
                          reportId: report.id,
                          photo: report.photo,
                          size: ReportPhotoSize.thumbnail,
                          semanticLabel: 'Foto do reporte já aberto',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colors.onTertiaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'É o mesmo buraco? Abra o reporte em vez de abrir outro.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onTertiaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(onPressed: onDismiss, child: const Text('É outro buraco')),
                FilledButton.tonal(
                  onPressed: onOpen,
                  style: AppTheme.tonalButtonStyle,
                  child: const Text('Ver o reporte'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
