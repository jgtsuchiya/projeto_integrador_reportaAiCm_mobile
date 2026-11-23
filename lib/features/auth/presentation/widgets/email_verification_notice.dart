import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/email_verification_controller.dart';

/// O aviso do e-mail ainda não confirmado, com o "Reenviar e-mail" (RM14). Aparece só com o
/// Client dentro e o `emailVerifiedAt` nulo: sem isso, não desenha nada. Serve a qualquer tela,
/// como a inicial e as dos reportes, que exigem o e-mail confirmado.
///
/// O "Reenviar e-mail" fica desativado por 1 minuto depois de cada envio e logo depois do
/// cadastro, com a contagem, e o leitor de tela anuncia o resultado do reenvio.
///
/// Enquanto o aviso está na tela, a volta do app para o primeiro plano atualiza o perfil (no
/// máximo uma vez a cada 30 s): depois de o Client confirmar o e-mail no navegador, o aviso some
/// sozinho.
class EmailVerificationNotice extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<EmailVerificationNotice> createState() => _EmailVerificationNoticeState();
}

class _EmailVerificationNoticeState extends ConsumerState<EmailVerificationNotice> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () =>
          unawaited(ref.read(emailVerificationControllerProvider.notifier).refreshOnResume()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = switch (ref.watch(authControllerProvider)) {
      AuthAuthenticated(:final profile) when profile.emailVerifiedAt == null => profile,
      _ => null,
    };
    if (profile == null) return const SizedBox.shrink();

    final verification = ref.watch(emailVerificationControllerProvider).forAccount(profile.email);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final feedback = verification.feedback;

    final buttonLabel = switch (verification.cooldownSeconds) {
      final seconds? => 'Reenviar e-mail em $seconds s',
      null => 'Reenviar e-mail',
    };

    return Card(
      margin: EdgeInsets.zero,
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.mark_email_unread_outlined, color: colors.onTertiaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'Confirme o seu e-mail',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colors.onTertiaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enviamos um link para ${profile.email}. Confirme o e-mail para abrir e '
                        'validar reportes.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (feedback != null) ...[
              const SizedBox(height: 12),
              // O leitor de tela anuncia o resultado do reenvio assim que ele aparece.
              Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      verification.isError ? Icons.error_outline : Icons.check_circle_outline,
                      size: 20,
                      color: colors.onTertiaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feedback,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _ResendButton(
                label: buttonLabel,
                isSending: verification.isSending,
                onPressed: verification.canResend
                    ? () =>
                          unawaited(ref.read(emailVerificationControllerProvider.notifier).resend())
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// O "Reenviar e-mail": com o envio em andamento, o indicador no lugar do ícone.
class _ResendButton extends StatelessWidget {
  const new({required this.label, required this.isSending, required this.onPressed});

  final String label;
  final bool isSending;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: isSending ? null : onPressed,
      icon: isSending
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: 'Enviando'),
            )
          : const Icon(Icons.send_outlined),
      label: Text(label),
    );
  }
}
