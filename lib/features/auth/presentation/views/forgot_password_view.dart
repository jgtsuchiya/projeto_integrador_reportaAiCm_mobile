import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/widgets/app_text_field.dart';
import 'package:reportaai_cm/core/widgets/primary_button.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';
import 'package:reportaai_cm/features/auth/presentation/view_models/forgot_password_view_model.dart';
import 'package:reportaai_cm/features/auth/presentation/views/login_view.dart';

/// "Esqueci minha senha" (`/esqueci-senha`), aberto pelo login com o e-mail que já estava digitado
/// (RM13). Pede o link para criar uma senha nova, que abre no navegador, na página do painel web.
///
/// Depois do pedido, a mensagem é sempre a mesma, com ou sem conta (RN20), o "Enviar de novo" fica
/// desativado por 1 minuto, com a contagem, e o "Voltar ao login" leva o e-mail para o login.
class ForgotPasswordView extends ConsumerStatefulWidget {
  const new({this.initialEmail = '', super.key});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends ConsumerState<ForgotPasswordView> {
  late final _email = TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() => ref.read(forgotPasswordViewModelProvider.notifier).submit(_email.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final forgotPassword = ref.watch(forgotPasswordViewModelProvider);
    final message = forgotPassword.message;

    final buttonLabel = switch (forgotPassword) {
      ForgotPasswordState(wasSent: false) => 'Enviar link',
      ForgotPasswordState(resendSeconds: final seconds?) => 'Enviar de novo em $seconds s',
      _ => 'Enviar de novo',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Esqueci minha senha')),
      body: SafeArea(
        child: ScrollableCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.lock_reset, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Informe o e-mail da sua conta. Vamos mandar um link para você criar uma senha nova.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'O link abre no navegador. Depois de criar a senha nova, volte ao app e entre com '
                'ela.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              AppTextField(
                label: 'E-mail',
                controller: _email,
                errorText: forgotPassword.emailError,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                onChanged: ref.read(forgotPasswordViewModelProvider.notifier).emailChanged,
                onFieldSubmitted: (_) => unawaited(_submit()),
              ),
              if (forgotPassword.wasSent) ...[const SizedBox(height: 16), const _SentNotice()],
              if (message != null) ...[
                const SizedBox(height: 16),
                // O leitor de tela anuncia o aviso assim que ele aparece. Na contagem do 429, só no
                // começo dela, e não a cada segundo.
                Semantics(
                  liveRegion: forgotPassword.announceMessage,
                  child: Text(
                    message,
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: buttonLabel,
                isLoading: forgotPassword.isSubmitting,
                onPressed:
                    forgotPassword.retrySeconds == null && forgotPassword.resendSeconds == null
                    ? () => unawaited(_submit())
                    : null,
              ),
              if (forgotPassword.wasSent) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => returnToLogin(context, LoginPrefill(email: _email.text.trim())),
                  child: const Text('Voltar ao login'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A mensagem depois do pedido, a mesma com ou sem conta (RN20).
class _SentNotice extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSecondaryContainer;

    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.secondaryContainer,
      // O leitor de tela anuncia a mensagem assim que ela aparece.
      child: Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.mark_email_read_outlined, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ForgotPasswordViewModel.sentMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
