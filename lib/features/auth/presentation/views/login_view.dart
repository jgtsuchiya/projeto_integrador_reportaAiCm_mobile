import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/routes.dart';
import 'package:reportaai_cm/core/widgets/app_text_field.dart';
import 'package:reportaai_cm/core/widgets/primary_button.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/view_models/login_view_model.dart';

/// Login (`/login`), para quem não tem sessão: o e-mail, a senha, o "Entrar" e o motivo de ter
/// voltado ao login, quando houver. Quem leva à tela inicial depois do login é o redirect das
/// rotas. Em debug, tem o atalho para o diagnóstico da API.
///
/// Provisória: a validação local (RM05), o autofill, os erros embaixo de cada campo e a contagem
/// regressiva do 429 (RM04) entram com a tela completa do login.
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

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() => unawaited(
    ref.read(loginViewModelProvider.notifier).submit(email: _email.text, password: _password.text),
  );

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
              Text(
                'Entrar no ReportaAi Cm',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              AppTextField(
                label: 'E-mail',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Senha',
                controller: _password,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              if (notice != null) ...[
                const SizedBox(height: 16),
                // O leitor de tela anuncia o aviso assim que ele aparece.
                Semantics(
                  liveRegion: true,
                  child: Text(
                    notice,
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(label: 'Entrar', isLoading: login.isSubmitting, onPressed: _submit),
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
