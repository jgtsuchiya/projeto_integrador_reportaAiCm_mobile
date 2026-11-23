import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/widgets/primary_button.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/change_password_view_model.dart';
import 'package:reportaai_cm/features/account/presentation/widgets/account_notice.dart';
import 'package:reportaai_cm/features/account/presentation/widgets/password_field.dart';
import 'package:reportaai_cm/features/auth/presentation/widgets/password_rules.dart';

/// "Trocar senha" (`/conta/senha`): a senha atual, a nova, com a regra visível, e a confirmação
/// (RM15 e RM16). Antes do botão, o aviso de que os outros aparelhos vão sair. Este aparelho
/// continua logado.
///
/// A senha atual errada aparece no campo, que é apagado, e nunca leva ao login. Com a senha
/// trocada, o gerenciador de senhas do aparelho oferece atualizar a senha guardada.
class ChangePasswordView extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends ConsumerState<ChangePasswordView> {
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    for (final controller in [_currentPassword, _newPassword, _confirmation]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final outcome = await ref
        .read(changePasswordViewModelProvider.notifier)
        .submit(
          currentPassword: _currentPassword.text,
          newPassword: _newPassword.text,
          confirmation: _confirmation.text,
        );
    if (!mounted) return;

    switch (outcome) {
      case ChangePasswordOutcome.changed:
        // A senha nova entrou: o gerenciador de senhas oferece atualizar a guardada.
        TextInput.finishAutofillContext();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text(ChangePasswordViewModel.changedMessage)));
        context.pop();
      case ChangePasswordOutcome.incorrectPassword:
        _currentPassword.clear();
      case null:
    }
  }

  void _fieldChanged(ChangePasswordField field) =>
      ref.read(changePasswordViewModelProvider.notifier).fieldChanged(field);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final changing = ref.watch(changePasswordViewModelProvider);
    final message = changing.message;

    return Scaffold(
      appBar: AppBar(title: const Text('Trocar senha')),
      body: SafeArea(
        child: ScrollableCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sem salvar ao sair da tela: a senha nova só é oferecida ao gerenciador de senhas
              // depois da troca, no `_submit`.
              AutofillGroup(
                onDisposeAction: AutofillContextAction.cancel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PasswordField(
                      label: 'Senha atual',
                      controller: _currentPassword,
                      errorText: changing.errorFor(ChangePasswordField.currentPassword),
                      autofillHints: const [AutofillHints.password],
                      onChanged: (_) => _fieldChanged(ChangePasswordField.currentPassword),
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      label: 'Senha nova',
                      controller: _newPassword,
                      errorText: changing.errorFor(ChangePasswordField.newPassword),
                      autofillHints: const [AutofillHints.newPassword],
                      onChanged: (_) => _fieldChanged(ChangePasswordField.newPassword),
                    ),
                    const SizedBox(height: 8),
                    PasswordRules(password: _newPassword),
                    const SizedBox(height: 16),
                    PasswordField(
                      label: 'Repita a senha nova',
                      controller: _confirmation,
                      errorText: changing.errorFor(ChangePasswordField.confirmation),
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => _fieldChanged(ChangePasswordField.confirmation),
                      onFieldSubmitted: (_) => unawaited(_submit()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const AccountNotice(
                icon: Icons.devices_outlined,
                text:
                    'Ao trocar a senha, os outros aparelhos saem da conta e vão precisar entrar de '
                    'novo. Este aparelho continua conectado.',
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
                label: 'Trocar senha',
                isLoading: changing.isSubmitting,
                onPressed: () => unawaited(_submit()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
