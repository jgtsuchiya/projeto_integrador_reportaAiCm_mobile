import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/widgets/primary_button.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/second_factor_settings_view_model.dart';
import 'package:reportaai_cm/features/account/presentation/widgets/account_notice.dart';
import 'package:reportaai_cm/features/account/presentation/widgets/password_field.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/widgets/email_verification_notice.dart';

/// "Verificação em duas etapas" (`/conta/verificacao`): o estado atual, o interruptor e, depois
/// de mexer nele, a senha atual que confirma a mudança (RN24 e RM15). Com a verificação ativa, o
/// login pede um código enviado por e-mail.
///
/// Ativar exige o e-mail confirmado: sem ele, a tela mostra o aviso do e-mail no lugar do
/// interruptor.
class SecondFactorSettingsView extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SecondFactorSettingsView> createState() => _SecondFactorSettingsViewState();
}

class _SecondFactorSettingsViewState extends ConsumerState<SecondFactorSettingsView> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final enabling = ref.read(secondFactorSettingsViewModelProvider).selected ?? false;
    final outcome = await ref
        .read(secondFactorSettingsViewModelProvider.notifier)
        .submit(_password.text);
    if (!mounted) return;

    switch (outcome) {
      case SecondFactorSettingsOutcome.changed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabling
                  ? SecondFactorSettingsViewModel.enabledMessage
                  : SecondFactorSettingsViewModel.disabledMessage,
            ),
          ),
        );
        context.pop();
      case SecondFactorSettingsOutcome.incorrectPassword:
        _password.clear();
      case null:
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(secondFactorSettingsViewModelProvider);
    final profile = switch (ref.watch(authControllerProvider)) {
      AuthAuthenticated(:final profile) => profile,
      _ => null,
    };
    if (profile == null) return const Scaffold(body: SizedBox.shrink());

    final selected = settings.selected;
    final message = settings.message;
    // Ativar exige o e-mail confirmado. Desativar, não.
    final needsVerifiedEmail = !profile.mfaEnabled && profile.emailVerifiedAt == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Verificação em duas etapas')),
      body: SafeArea(
        child: ScrollableCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Com a verificação ativa, cada login pede, além da senha, um código de 6 dígitos '
                'enviado para o seu e-mail.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              if (needsVerifiedEmail)
                const EmailVerificationNotice()
              else
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: SwitchListTile(
                    title: const Text('Pedir o código no login'),
                    subtitle: Text(profile.mfaEnabled ? 'Ativada' : 'Desativada'),
                    value: selected ?? profile.mfaEnabled,
                    onChanged: settings.isSubmitting
                        ? null
                        : (enabled) => ref
                              .read(secondFactorSettingsViewModelProvider.notifier)
                              .select(enabled: enabled),
                  ),
                ),
              if (selected != null) ...[
                const SizedBox(height: 24),
                AccountNotice(
                  icon: selected ? Icons.devices_outlined : Icons.info_outline,
                  text: selected
                      ? 'Ao ativar, os outros aparelhos saem da conta e vão pedir o código no '
                            'próximo login. Este aparelho continua conectado.'
                      : 'Ao desativar, o login volta a pedir só o e-mail e a senha.',
                ),
                const SizedBox(height: 16),
                AutofillGroup(
                  onDisposeAction: AutofillContextAction.cancel,
                  child: PasswordField(
                    label: 'Senha atual',
                    controller: _password,
                    errorText: settings.passwordError,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onChanged: (_) =>
                        ref.read(secondFactorSettingsViewModelProvider.notifier).passwordChanged(),
                    onFieldSubmitted: (_) => unawaited(_submit()),
                  ),
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
                  label: selected ? 'Ativar a verificação' : 'Desativar a verificação',
                  isLoading: settings.isSubmitting,
                  onPressed: () => unawaited(_submit()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
