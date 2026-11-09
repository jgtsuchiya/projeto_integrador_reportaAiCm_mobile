import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/routes.dart';
import 'package:reportaai_cm/core/widgets/app_text_field.dart';
import 'package:reportaai_cm/core/widgets/primary_button.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';
import 'package:reportaai_cm/features/auth/domain/models/sign_in_result.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/view_models/login_view_model.dart';

/// Login (`/login`), para quem não tem sessão: o e-mail, a senha, o "Entrar" e o motivo de ter
/// voltado ao login, quando houver. Os erros de cada campo ficam embaixo dele, e o aviso geral,
/// acima do "Entrar". Quem leva à tela inicial depois do login é o redirect das rotas. Em debug,
/// tem o atalho para o diagnóstico da API.
///
/// Os campos ficam num `AutofillGroup`, para o gerenciador de senhas do aparelho preencher e, depois
/// do login, oferecer salvar o e-mail e a senha.
class LoginView extends ConsumerStatefulWidget {
  const new({this.showDiagnostics = kDebugMode, super.key});

  /// Segue a rota de diagnóstico, que só existe em debug.
  final bool showDiagnostics;

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final result = await ref
        .read(loginViewModelProvider.notifier)
        .submit(email: _email.text, password: _password.text);

    if (result is SignInSuccess) {
      // O gerenciador de senhas oferece salvar só o e-mail e a senha que entraram.
      TextInput.finishAutofillContext();
    } else if (result is SignInWrongCredentials && mounted) {
      // O e-mail continua preenchido, e a senha é apagada (RM02).
      _password.clear();
    }
  }

  void _fieldChanged(SignInField field) =>
      ref.read(loginViewModelProvider.notifier).fieldChanged(field);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final login = ref.watch(loginViewModelProvider);
    final reason = switch (ref.watch(authControllerProvider)) {
      AuthUnauthenticated(:final reason) => reason,
      _ => null,
    };
    final notice = login.message ?? reason?.message;

    return Scaffold(
      body: SafeArea(
        child: ScrollableCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.add_road, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  'Entrar no ReportaAi Cm',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              // Sem salvar ao sair da tela: o e-mail e a senha só são oferecidos ao gerenciador de
              // senhas depois de um login que entrou, no `_submit`.
              AutofillGroup(
                onDisposeAction: AutofillContextAction.cancel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      label: 'E-mail',
                      controller: _email,
                      errorText: login.errorFor(SignInField.email),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      onChanged: (_) => _fieldChanged(SignInField.email),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Senha',
                      controller: _password,
                      errorText: login.errorFor(SignInField.password),
                      textInputAction: TextInputAction.done,
                      obscureText: !_isPasswordVisible,
                      // Também com a senha visível, o teclado não corrige nem aprende a senha.
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.password],
                      onChanged: (_) => _fieldChanged(SignInField.password),
                      onFieldSubmitted: (_) => unawaited(_submit()),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                        tooltip: _isPasswordVisible ? 'Ocultar senha' : 'Mostrar senha',
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (notice != null) ...[
                const SizedBox(height: 16),
                // O leitor de tela anuncia o aviso assim que ele aparece. Na contagem do 429, só no
                // começo dela, e não a cada segundo.
                Semantics(
                  liveRegion: login.announceMessage,
                  child: Text(
                    notice,
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Na contagem do 429, o "Entrar" fica desativado e volta sozinho no fim dela (RM04).
              PrimaryButton(
                label: 'Entrar',
                isLoading: login.isSubmitting,
                onPressed: login.retrySeconds == null ? () => unawaited(_submit()) : null,
              ),
              if (widget.showDiagnostics) ...[
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => unawaited(context.push(AppRoutes.diagnostics)),
                  icon: const Icon(Icons.monitor_heart_outlined),
                  label: const Text('Diagnóstico da API'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
