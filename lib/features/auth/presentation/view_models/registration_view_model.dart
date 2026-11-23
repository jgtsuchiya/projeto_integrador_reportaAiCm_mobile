import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/core/utils/countdown.dart';
import 'package:reportaai_cm/core/utils/date_formatters.dart';
import 'package:reportaai_cm/core/utils/masked_input_formatter.dart';
import 'package:reportaai_cm/features/auth/auth_providers.dart';
import 'package:reportaai_cm/features/auth/domain/models/client_registration.dart';
import 'package:reportaai_cm/features/auth/domain/models/registration_result.dart';
import 'package:reportaai_cm/features/auth/domain/models/registration_validation.dart';
import 'package:reportaai_cm/features/auth/domain/models/sign_in_result.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/email_verification_controller.dart';

/// Estado da tela de cadastro: o envio em andamento, o erro de cada campo, o aviso geral e a
/// contagem regressiva do limite por IP.
final NotifierProvider<RegistrationViewModel, RegistrationState> registrationViewModelProvider =
    NotifierProvider.autoDispose(RegistrationViewModel.new);

@immutable
final class RegistrationState {
  const new({
    this.isSubmitting = false,
    this.fieldErrors = const {},
    this.alreadyInUse,
    this.message,
    this.retrySeconds,
    this.announceMessage = true,
  });

  /// Do toque no "Criar conta" até o fim do login automático.
  final bool isSubmitting;

  /// O erro de cada campo, da conferência antes de enviar ou da API (400 e 409), para mostrar
  /// embaixo dele (RM11).
  final Map<RegistrationField, String> fieldErrors;

  /// O campo que já tem conta, no 409: o e-mail ou o CPF.
  final RegistrationField? alreadyInUse;

  /// O aviso geral, acima do "Criar conta", como sem conexão.
  final String? message;

  /// Na contagem regressiva do limite por IP, os segundos que faltam para o "Criar conta"
  /// voltar. `null` fora da contagem.
  final int? retrySeconds;

  /// Se o leitor de tela anuncia o [message]. Na contagem do 429, só quando ela começa.
  final bool announceMessage;

  /// Se o "Criar conta" envia: nem durante o envio, nem durante a contagem do 429.
  bool get canSubmit => !isSubmitting && retrySeconds == null;

  /// Se o e-mail digitado já tem conta (409): a tela oferece o "Entrar" e o "Esqueci minha senha".
  bool get isEmailInUse =>
      alreadyInUse == RegistrationField.email && fieldErrors.containsKey(RegistrationField.email);

  /// O erro do [field], ou `null` quando ele não tem erro.
  String? errorFor(RegistrationField field) => fieldErrors[field];

  @override
  bool operator ==(Object other) =>
      other is RegistrationState &&
      other.isSubmitting == isSubmitting &&
      mapEquals(other.fieldErrors, fieldErrors) &&
      other.alreadyInUse == alreadyInUse &&
      other.message == message &&
      other.retrySeconds == retrySeconds &&
      other.announceMessage == announceMessage;

  @override
  int get hashCode => Object.hash(
    isSubmitting,
    Object.hashAllUnordered([
      for (final MapEntry(:key, :value) in fieldErrors.entries) Object.hash(key, value),
    ]),
    alreadyInUse,
    message,
    retrySeconds,
    announceMessage,
  );

  @override
  String toString() =>
      'RegistrationState(isSubmitting: $isSubmitting, fieldErrors: $fieldErrors, '
      'alreadyInUse: ${alreadyInUse?.name}, message: $message, retrySeconds: $retrySeconds, '
      'announceMessage: $announceMessage)';
}

/// Como terminou um cadastro que criou a conta.
enum RegistrationOutcome {
  /// O login automático entrou: o redirect leva à tela inicial (RM12).
  signedIn,

  /// A conta foi criada, mas o login automático não entrou (ex.: sem conexão): a tela leva ao
  /// login, com o e-mail preenchido (RM12).
  signInFailed,
}

/// Confere os campos, cria a conta e entra com o e-mail e a senha digitados (RM11 e RM12). Quem
/// leva à tela inicial é o redirect das rotas, a partir do estado de login.
final class RegistrationViewModel extends Notifier<RegistrationState> {
  static const accountCreatedMessage = 'Sua conta foi criada. Entre com o e-mail e a senha.';

  late final _countdown = Countdown(_tick);

  @override
  RegistrationState build() {
    ref.onDispose(_countdown.cancel);
    return const RegistrationState();
  }

  /// Cria a conta com os campos como estão na tela, com a máscara, depois de conferir as regras
  /// da API (RM11): com um campo recusado, a API não é chamada. Um envio durante outro, ou durante
  /// a contagem do 429, é ignorado.
  ///
  /// Com a conta criada, entra pelo `AuthController` (RM12) e devolve o [RegistrationOutcome].
  /// Devolve `null` quando a conta não foi criada. A senha não fica guardada: só o gerenciador de
  /// senhas do aparelho a salva.
  Future<RegistrationOutcome?> submit({
    required String name,
    required String email,
    required String password,
    required String cpf,
    required String phone,
    required String birthDate,
  }) async {
    if (!state.canSubmit) return null;

    // A data incompleta vai como foi digitada, e a conferência a recusa pelo formato.
    final isoBirthDate = maskedDateToIso(birthDate) ?? birthDate.trim();
    final fieldErrors = validateRegistration(
      name: name,
      email: email,
      password: password,
      cpf: cpf,
      phone: phone,
      birthDate: isoBirthDate,
    );
    if (fieldErrors.isNotEmpty) {
      state = RegistrationState(fieldErrors: fieldErrors);
      return null;
    }

    state = const RegistrationState(isSubmitting: true);

    final RegistrationResult result;
    try {
      result = await ref
          .read(registrationRepositoryProvider)
          .register(
            ClientRegistration(
              name: name,
              email: email,
              password: password,
              cpf: digitsOnly(cpf),
              phone: digitsOnly(phone),
              birthDate: isoBirthDate,
            ),
          );
    } on Object catch (error) {
      if (ref.mounted) state = RegistrationState(message: ApiException.messageOf(error));
      return null;
    }

    // O usuário saiu da tela durante o envio: a conta pode ter sido criada, e ele entra pelo login.
    if (!ref.mounted) return null;

    switch (result) {
      case RegistrationSuccess():
        return await _signIn(email: email, password: password);
      case RegistrationFieldErrors(:final errors, :final alreadyInUse):
        state = RegistrationState(fieldErrors: errors, alreadyInUse: alreadyInUse);
        return null;
      case RegistrationRateLimited(:final retryAfter):
        final seconds = countdownSecondsOf(retryAfter);
        state = _rateLimited(seconds);
        _countdown.start(seconds);
        return null;
    }
  }

  /// O usuário editou o [field]: o erro dele sai da tela, e o dos outros campos continua.
  void fieldChanged(RegistrationField field) {
    if (state.errorFor(field) == null) return;

    state = RegistrationState(
      fieldErrors: Map.unmodifiable({...state.fieldErrors}..remove(field)),
      alreadyInUse: state.alreadyInUse == field ? null : state.alreadyInUse,
    );
  }

  /// O login automático, depois da conta criada (RM12).
  Future<RegistrationOutcome> _signIn({required String email, required String password}) async {
    // O cadastro já mandou o link de confirmação: o "Reenviar e-mail" espera 1 minuto (RM14).
    ref.read(emailVerificationControllerProvider.notifier).markSent(email);
    final auth = ref.read(authControllerProvider.notifier);

    try {
      final result = await auth.signIn(email: email, password: password);
      if (result is SignInSuccess) return RegistrationOutcome.signedIn;
    } on Object {
      // Sem conexão ou com a API fora do ar no login: a conta existe, e o usuário entra pelo login.
    }

    if (ref.mounted) state = const RegistrationState();
    return RegistrationOutcome.signInFailed;
  }

  /// Um segundo da contagem do 429. No fim dela, o aviso sai e o "Criar conta" volta sozinho.
  void _tick(int secondsLeft) {
    state = secondsLeft > 0
        ? _rateLimited(secondsLeft, announce: false)
        : const RegistrationState();
  }
}

/// A contagem do limite por IP, com os [seconds] que faltam.
RegistrationState _rateLimited(int seconds, {bool announce = true}) => RegistrationState(
  message: 'Muitas tentativas. Tente de novo em $seconds s.',
  retrySeconds: seconds,
  announceMessage: announce,
);
