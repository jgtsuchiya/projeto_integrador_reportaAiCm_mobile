import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/utils/date_formatters.dart';
import 'package:reportaai_cm/core/widgets/error_view.dart';
import 'package:reportaai_cm/core/widgets/loading_indicator.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';
import 'package:reportaai_cm/features/account/domain/models/user_session.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/sessions_view_model.dart';

/// "Sessões abertas" (`/conta/sessoes`): os aparelhos em que a conta está aberta, com a data e a
/// hora do login, o aparelho e o IP (RM19). A sessão deste aparelho vem primeiro, marcada "Este
/// aparelho", sem o "Encerrar". O "Encerrar" e o "Encerrar todas as outras" pedem confirmação.
///
/// Puxar para atualizar busca a lista de novo.
class SessionsView extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SessionsView> createState() => _SessionsViewState();
}

class _SessionsViewState extends ConsumerState<SessionsView> {
  SessionsViewModel get _viewModel => ref.read(sessionsViewModelProvider.notifier);

  Future<void> _revoke(UserSession session) async {
    final confirmed = await _confirm(
      title: 'Encerrar esta sessão?',
      content: '${session.device.label} sai da conta em até 15 minutos.',
    );
    if (!confirmed) return;

    _showMessage(await _viewModel.revoke(session.id));
  }

  Future<void> _revokeOthers() async {
    final confirmed = await _confirm(
      title: 'Encerrar as outras sessões?',
      content:
          'Todos os outros aparelhos saem da conta em até 15 minutos. Este aparelho continua '
          'conectado.',
    );
    if (!confirmed) return;

    _showMessage(await _viewModel.revokeOthers());
  }

  /// Pergunta antes de encerrar. Fora do diálogo (o "voltar" ou um toque fora dele), não encerra.
  Future<bool> _confirm({required String title, required String content}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
    return confirmed == true && mounted;
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsViewModelProvider);
    final list = sessions.sessions;
    final loadError = sessions.loadError;

    final Widget body;
    if (list == null && loadError != null) {
      body = ErrorView(
        title: 'As sessões não carregaram',
        message: loadError,
        onRetry: () => unawaited(_viewModel.load()),
      );
    } else if (list == null) {
      body = const LoadingIndicator(message: 'Carregando as sessões');
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (loadError != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          'A lista não foi atualizada. $loadError',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    for (final session in list) ...[
                      _SessionCard(
                        session: session,
                        isRevoking: sessions.revokingIds.contains(session.id),
                        onRevoke: () => unawaited(_revoke(session)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (sessions.hasOtherSessions) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: sessions.isRevokingOthers
                            ? null
                            : () => unawaited(_revokeOthers()),
                        icon: const Icon(Icons.logout),
                        label: const Text('Encerrar todas as outras'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sessões abertas')),
      body: SafeArea(child: body),
    );
  }
}

/// Uma sessão: o aparelho, a data e a hora do login, o IP e o "Encerrar" ou o "Este aparelho".
class _SessionCard extends StatelessWidget {
  const new({required this.session, required this.isRevoking, required this.onRevoke});

  final UserSession session;
  final bool isRevoking;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final device = session.device;
    final ipAddress = session.ipAddress;
    final secondary = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(switch (device.kind) {
              SessionDeviceKind.app => Icons.phone_android,
              SessionDeviceKind.browser => Icons.language,
              SessionDeviceKind.unknown => Icons.devices_other,
            }, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // O leitor de tela lê os dados da sessão juntos, e o "Encerrar" à parte.
                  MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(device.label, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Entrou em ${formatDateTime(session.createdAt.toLocal())}',
                          style: secondary,
                        ),
                        if (ipAddress != null) Text('IP $ipAddress', style: secondary),
                        if (session.current) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Este aparelho',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Para sair da sessão deste aparelho, o "Sair". O botão fica embaixo dos dados,
                  // para caber com a fonte grande.
                  if (!session.current)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: isRevoking ? null : onRevoke,
                        child: const Text('Encerrar'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
