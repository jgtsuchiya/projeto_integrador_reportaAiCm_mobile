import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/utils/cpf_formatters.dart';
import 'package:reportaai_cm/core/utils/date_formatters.dart';
import 'package:reportaai_cm/core/utils/phone_formatters.dart';
import 'package:reportaai_cm/core/widgets/app_text_field.dart';
import 'package:reportaai_cm/core/widgets/primary_button.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';
import 'package:reportaai_cm/features/auth/domain/models/client_registration.dart';
import 'package:reportaai_cm/features/auth/presentation/view_models/registration_view_model.dart';
import 'package:reportaai_cm/features/auth/presentation/views/login_view.dart';
import 'package:reportaai_cm/features/auth/presentation/widgets/password_rules.dart';

/// Cadastro do Client (`/cadastro`), aberto pelo "Criar conta" do login (RM11 e RM12): o nome, o
/// e-mail, a senha com a regra, o CPF, o telefone e a data de nascimento, com as máscaras.
///
/// Os erros de cada campo, da conferência antes de enviar ou da API, ficam embaixo dele. Com a
/// conta criada, o app entra sozinho, e o redirect leva à tela inicial. Se o login automático não
/// entrar, a tela volta ao login com o e-mail preenchido.
///
/// Os campos ficam num `AutofillGroup`: com a conta criada, o gerenciador de senhas do aparelho
/// oferece salvar o e-mail e a senha nova.
class RegistrationView extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<RegistrationView> createState() => _RegistrationViewState();
}

class _RegistrationViewState extends ConsumerState<RegistrationView> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _cpf = TextEditingController();
  final _phone = TextEditingController();
  final _birthDate = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    for (final controller in [_name, _email, _password, _cpf, _phone, _birthDate]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final outcome = await ref
        .read(registrationViewModelProvider.notifier)
        .submit(
          name: _name.text,
          email: _email.text,
          password: _password.text,
          cpf: _cpf.text,
          phone: _phone.text,
          birthDate: _birthDate.text,
        );
    if (outcome == null) return;

    // A conta foi criada com esta senha: o gerenciador de senhas oferece salvar (RM12).
    TextInput.finishAutofillContext();

    if (outcome == RegistrationOutcome.signInFailed && mounted) {
      returnToLogin(
        context,
        LoginPrefill(
          email: _email.text.trim(),
          notice: RegistrationViewModel.accountCreatedMessage,
        ),
      );
    }
  }

  void _fieldChanged(RegistrationField field) =>
      ref.read(registrationViewModelProvider.notifier).fieldChanged(field);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final registration = ref.watch(registrationViewModelProvider);
    final message = registration.message;

    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: ScrollableCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Com a conta, você reporta os buracos da cidade e acompanha cada reporte.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              // Sem salvar ao sair da tela: o e-mail e a senha só são oferecidos ao gerenciador de
              // senhas depois de a conta ser criada, no `_submit`.
              AutofillGroup(
                onDisposeAction: AutofillContextAction.cancel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      label: 'Nome completo',
                      controller: _name,
                      errorText: registration.errorFor(RegistrationField.name),
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      onChanged: (_) => _fieldChanged(RegistrationField.name),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'E-mail',
                      controller: _email,
                      errorText: registration.errorFor(RegistrationField.email),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      onChanged: (_) => _fieldChanged(RegistrationField.email),
                    ),
                    if (registration.isEmailInUse)
                      _EmailInUseActions(
                        onSignIn: () =>
                            returnToLogin(context, LoginPrefill(email: _email.text.trim())),
                        onForgotPassword: () => returnToLogin(
                          context,
                          LoginPrefill(email: _email.text.trim(), openForgotPassword: true),
                        ),
                      ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Senha',
                      controller: _password,
                      errorText: registration.errorFor(RegistrationField.password),
                      textInputAction: TextInputAction.next,
                      obscureText: !_isPasswordVisible,
                      // Também com a senha visível, o teclado não corrige nem aprende a senha.
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.newPassword],
                      onChanged: (_) => _fieldChanged(RegistrationField.password),
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
                    const SizedBox(height: 8),
                    PasswordRules(password: _password),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'CPF',
                      controller: _cpf,
                      errorText: registration.errorFor(RegistrationField.cpf),
                      hintText: '000.000.000-00',
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      inputFormatters: const [CpfInputFormatter()],
                      onChanged: (_) => _fieldChanged(RegistrationField.cpf),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Telefone',
                      controller: _phone,
                      errorText: registration.errorFor(RegistrationField.phone),
                      hintText: '(00) 00000-0000',
                      helperText: 'Com o DDD',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      inputFormatters: const [PhoneInputFormatter()],
                      onChanged: (_) => _fieldChanged(RegistrationField.phone),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Data de nascimento',
                      controller: _birthDate,
                      errorText: registration.errorFor(RegistrationField.birthDate),
                      hintText: 'dd/mm/aaaa',
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      inputFormatters: const [DateInputFormatter()],
                      onChanged: (_) => _fieldChanged(RegistrationField.birthDate),
                      onFieldSubmitted: (_) => unawaited(_submit()),
                      // Com o teclado aberto no último campo, a tela rola até o "Criar conta".
                      scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 240),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _EmailVerificationHint(),
              if (message != null) ...[
                const SizedBox(height: 16),
                // O leitor de tela anuncia o aviso assim que ele aparece. Na contagem do 429, só no
                // começo dela, e não a cada segundo.
                Semantics(
                  liveRegion: registration.announceMessage,
                  child: Text(
                    message,
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Criar conta',
                isLoading: registration.isSubmitting,
                onPressed: registration.retrySeconds == null ? () => unawaited(_submit()) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Os atalhos do e-mail que já tem conta (409): voltar ao login com o e-mail, ou pedir o link para
/// criar uma senha nova.
class _EmailInUseActions extends StatelessWidget {
  const new({required this.onSignIn, required this.onForgotPassword});

  final VoidCallback onSignIn;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 8,
        children: [
          TextButton(onPressed: onSignIn, child: const Text('Entrar')),
          TextButton(onPressed: onForgotPassword, child: const Text('Esqueci minha senha')),
        ],
      ),
    );
  }
}

/// O aviso de que o app manda o link para confirmar o e-mail, antes do "Criar conta".
class _EmailVerificationHint extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.mark_email_unread_outlined, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Depois do cadastro, vamos mandar um link para o seu e-mail. Confirme o e-mail para '
            'abrir e validar reportes.',
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
