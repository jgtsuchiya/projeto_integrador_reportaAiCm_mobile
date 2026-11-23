import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/widgets/email_verification_notice.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_limits.dart';
import 'package:reportaai_cm/features/reports/domain/models/vote_type.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_vote_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/report_location_card.dart';

/// O texto do voto já dado, no detalhe e na lista dos reportes perto.
String myVoteText(VoteType vote) => switch (vote) {
  VoteType.confirm => 'Você confirmou',
  VoteType.deny => 'Você disse que não está lá',
};

/// O voto no reporte de outro cidadão (RM29 e RM30): o "Está lá" e o "Não está lá", com a
/// confirmação, ou o voto já dado ("Você confirmou"). Os botões aparecem só com o `canVote` da API.
///
/// Antes de enviar, o app lê a localização atual, com as regras da abertura (RM21). Se ela não
/// servir, o motivo aparece no lugar dos botões, com a ação que resolve, e o voto segue depois
/// dela. Sem o e-mail confirmado, o aviso com o reenvio fica no lugar dos botões (RM20).
class ReportVoteBar extends ConsumerStatefulWidget {
  const new({required this.report, this.compact = false, super.key});

  final Report report;

  /// Na lista dos reportes perto: sem a explicação e sem o aviso do e-mail, que a lista mostra uma
  /// vez só, em cima.
  final bool compact;

  /// Se a barra mostra algo para o [report]: o voto já dado, ou o voto que a API permite. O
  /// reporte do próprio cidadão nunca tem voto (RN37).
  static bool appliesTo(Report report) =>
      !report.isMine && (report.votes.mine != null || report.canVote);

  @override
  ConsumerState<ReportVoteBar> createState() => _ReportVoteBarState();
}

class _ReportVoteBarState extends ConsumerState<ReportVoteBar> {
  late final AppLifecycleListener _lifecycle;

  ReportVoteViewModel get _viewModel =>
      ref.read(reportVoteViewModelProvider(widget.report.id).notifier);

  @override
  void initState() {
    super.initState();
    // Na volta das configurações do aparelho, a localização liberada é lida de novo.
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_handle(_viewModel.onResume())));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Pede a confirmação e, com ela, vota (RM29).
  Future<void> _confirm(VoteType vote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // Com a fonte grande num celular pequeno, a pergunta e os botões rolam.
        scrollable: true,
        title: Text(switch (vote) {
          VoteType.confirm => 'Confirmar que o buraco está lá?',
          VoteType.deny => 'Confirmar que o buraco não está lá?',
        }),
        content: const Text('O voto não pode ser desfeito.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _handle(_viewModel.vote(vote));
  }

  /// Espera o voto e avisa quando ele foi registrado. O motivo do voto que não foi fica no estado.
  Future<void> _handle(Future<Report?> voting) async {
    // O aviso aparece na tela de agora: a barra pode sair da árvore com a lista atualizada.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final report = await voting;
    if (report == null) return;

    messenger?.showSnackBar(SnackBar(content: Text(ReportVoteViewModel.votedMessageFor(report))));
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    if (!ReportVoteBar.appliesTo(report)) return const SizedBox.shrink();

    final myVote = report.votes.mine;
    if (myVote != null) return _MyVote(vote: myVote);

    final isEmailVerified = switch (ref.watch(authControllerProvider)) {
      AuthAuthenticated(:final profile) => profile.emailVerifiedAt != null,
      _ => false,
    };
    if (!isEmailVerified) {
      if (widget.compact) return const SizedBox.shrink();
      return const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EmailVerificationNotice(),
          SizedBox(height: 8),
          Text('Depois de confirmar o e-mail, volte aqui para votar.'),
        ],
      );
    }

    final state = ref.watch(reportVoteViewModelProvider(report.id));
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final location = state.location;
    final message = state.message;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact) ...[
          Semantics(
            header: true,
            child: Text('O buraco ainda está lá?', style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: 4),
          Text(
            'Vote só se você estiver perto dele, a até ${ReportLimits.nearbyRadiusMeters} m. O app '
            'confere a sua localização, que não fica guardada.',
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
        ],
        if (state.step == VoteStep.blocked && location != null) ...[
          ReportLocationCard(
            reading: location,
            purpose: LocationPurpose.vote,
            onRefresh: () => unawaited(_handle(_viewModel.refreshLocation())),
            onRequestPermission: () => unawaited(_handle(_viewModel.requestLocationPermission())),
            onOpenAppSettings: () => unawaited(_viewModel.openAppSettings()),
            onOpenLocationSettings: () => unawaited(_viewModel.openLocationSettings()),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(onPressed: _viewModel.cancel, child: const Text('Cancelar o voto')),
          ),
        ] else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _VoteButton(
                vote: VoteType.confirm,
                state: state,
                onPressed: () => unawaited(_confirm(VoteType.confirm)),
              ),
              _VoteButton(
                vote: VoteType.deny,
                state: state,
                onPressed: () => unawaited(_confirm(VoteType.deny)),
              ),
            ],
          ),
          if (state.step.isBusy) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                state.step == VoteStep.locating
                    ? 'Conferindo a sua localização…'
                    : 'Enviando o voto…',
                style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ],
        if (message != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: colors.error)),
          ),
        ],
      ],
    );
  }
}

/// O "Está lá" (cheio) ou o "Não está lá" (contornado). Durante o voto, os dois ficam desativados,
/// e o escolhido mostra o carregando.
class _VoteButton extends StatelessWidget {
  const new({required this.vote, required this.state, required this.onPressed});

  final VoteType vote;
  final ReportVoteState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isBusy = state.step.isBusy;
    final onPressed = isBusy ? null : this.onPressed;
    final label = Text(switch (vote) {
      VoteType.confirm => 'Está lá',
      VoteType.deny => 'Não está lá',
    });
    final icon = isBusy && state.vote == vote
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: 'Votando'),
          )
        : Icon(vote == VoteType.confirm ? Icons.check : Icons.close);

    return switch (vote) {
      VoteType.confirm => FilledButton.icon(onPressed: onPressed, icon: icon, label: label),
      VoteType.deny => OutlinedButton.icon(onPressed: onPressed, icon: icon, label: label),
    };
  }
}

/// O voto que o cidadão já deu: não muda depois de dado (RN37).
class _MyVote extends StatelessWidget {
  const new({required this.vote});

  final VoteType vote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MergeSemantics(
      child: Row(
        children: [
          Icon(
            vote == VoteType.confirm ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(myVoteText(vote), style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
