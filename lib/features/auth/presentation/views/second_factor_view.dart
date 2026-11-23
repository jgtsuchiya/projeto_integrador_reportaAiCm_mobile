import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/widgets/app_text_field.dart';
import 'package:reportaai_cm/core/widgets/primary_button.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';
import 'package:reportaai_cm/features/auth/presentation/view_models/second_factor_view_model.dart';
import 'package:reportaai_cm/features/auth/presentation/widgets/sign_out_button.dart';

/// Código da verificação em duas etapas (`/verificacao`), com a sessão pendente da segunda etapa
/// (RM18): o campo de 6 dígitos, o "Confirmar", o "Enviar outro código" e o "Sair". O redirect
/// abre esta tela depois do login e na abertura, enquanto a sessão estiver pendente, e leva à tela
/// inicial depois do código certo.
///
/// O "Sair" encerra a sessão pendente e volta ao login.
class SecondFactorView extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SecondFactorView> createState() => _SecondFactorViewState();
}

class _SecondFactorViewState extends ConsumerState<SecondFactorView> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() => ref.read(secondFactorViewModelProvider.notifier).submit(_code.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verification = ref.watch(secondFactorViewModelProvider);
    final message = verification.message;
    final notice = verification.notice;

    final resendLabel = switch (verification.resendSeconds) {
      final seconds? => 'Enviar outro código em $seconds s',
      null => 'Enviar outro código',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificação em duas etapas'),
        // Não há tela atrás: o "voltar" fecha o app, e o "Sair" volta ao login.
        automaticallyImplyLeading: false,
        actions: const [SignOutButton()],
      ),
      body: SafeArea(
        child: ScrollableCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.mark_email_read_outlined, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  'Confira o seu e-mail',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enviamos um código de ${SecondFactorViewModel.codeLength} dígitos para o e-mail '
                'da sua conta. O código vale por 10 minutos.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              AppTextField(
                label: 'Código',
                controller: _code,
                errorText: verification.codeError,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                // O teclado do aparelho pode oferecer o código que chegou por e-mail.
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(SecondFactorViewModel.codeLength),
                ],
                onChanged: (_) => ref.read(secondFactorViewModelProvider.notifier).codeChanged(),
                onFieldSubmitted: (_) => unawaited(_submit()),
              ),
              if (verification.isCodeInvalidated) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    SecondFactorViewModel.invalidatedMessage,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (message != null) ...[
                const SizedBox(height: 16),
                // O leitor de tela anuncia o aviso assim que ele aparece.
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (notice != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    notice,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Confirmar',
                isLoading: verification.isSubmitting,
                onPressed: () => unawaited(_submit()),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: verification.canResend
                    ? () => unawaited(ref.read(secondFactorViewModelProvider.notifier).resend())
                    : null,
                child: Text(resendLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
