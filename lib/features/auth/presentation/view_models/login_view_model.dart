import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/domain/models/sign_in_result.dart';
import 'package:reportaai_cm/features/auth/domain/models/sign_in_validation.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';

/// Estado da tela de login: o envio em andamento, o erro de cada campo, o aviso geral do último
/// login que não entrou e a contagem regressiva do limite por IP.
final NotifierProvider<LoginViewModel, LoginState> loginViewModelProvider =
    NotifierProvider.autoDispose(LoginViewModel.new);

@immutable
final class LoginState {
  const new({
    this.isSubmitting = false,
    this.fieldErrors = const {},
    this.message,
    this.retrySeconds,
    this.announceMessage = true,
  });

  final bool isSubmitting;

  /// O erro de cada campo, da conferência antes de enviar (RM05) ou do `FIELD_ERROR` da API, para
  /// mostrar embaixo dele.
  final Map<SignInField, String> fieldErrors;

  /// O aviso geral do último login que não entrou, acima do "Entrar", como "E-mail ou senha
  /// incorretos.".
  final String? message;

  /// Na contagem regressiva do limite por IP (RM04), os segundos que faltam para o "Entrar"
  /// voltar. `null` fora da contagem.
  final int? retrySeconds;

  /// Se o leitor de tela anuncia o [message]. Na contagem do 429, o aviso muda a cada segundo: ele
  /// é anunciado quando aparece, e não a cada segundo.
  final bool announceMessage;

  /// Se o "Entrar" envia: nem durante o envio, nem durante a contagem do 429.
  bool get canSubmit => !isSubmitting && retrySeconds == null;

  /// O erro do [field], ou `null` quando ele não tem erro.
  String? errorFor(SignInField field) => fieldErrors[field];

  @override
  bool operator ==(Object other) =>
      other is LoginState &&
      other.isSubmitting == isSubmitting &&
      mapEquals(other.fieldErrors, fieldErrors) &&
      other.message == message &&
      other.retrySeconds == retrySeconds &&
      other.announceMessage == announceMessage;

  @override
  int get hashCode => Object.hash(
    isSubmitting,
    Object.hashAllUnordered([
      for (final MapEntry(:key, :value) in fieldErrors.entries) Object.hash(key, value),
    ]),
    message,
    retrySeconds,
    announceMessage,
  );

  @override
  String toString() =>
      'LoginState(isSubmitting: $isSubmitting, fieldErrors: $fieldErrors, message: $message, '
      'retrySeconds: $retrySeconds, announceMessage: $announceMessage)';
}

/// Confere os campos e envia o login pelo `AuthController`. Quem leva à tela inicial é o redirect
/// das rotas, a partir do estado de login: o ViewModel guarda só o estado da tela.
final class LoginViewModel extends Notifier<LoginState> {
  static const wrongCredentialsMessage = 'E-mail ou senha incorretos.';

  /// A contagem regressiva do 429 (RM04): tira um segundo do `retrySeconds` a cada tique.
  Timer? _countdown;

  @override
  LoginState build() {
    ref.onDispose(() => _countdown?.cancel());
    return const LoginState();
  }

  /// Entra com o [email] e a [password], depois de conferir os campos (RM05): com um campo
  /// recusado, a API não é chamada. Um envio durante outro, ou durante a contagem do 429, é
  /// ignorado.
  ///
  /// Devolve o resultado do login, para a tela apagar a senha recusada (RM02) e oferecer salvar a
  /// senha que entrou. Devolve `null` quando o login não foi enviado ou não teve resposta, como
  /// sem conexão.
  Future<SignInResult?> submit({required String email, required String password}) async {
    if (!state.canSubmit) return null;

    final fieldErrors = validateSignIn(email: email, password: password);
    if (fieldErrors.isNotEmpty) {
      state = LoginState(fieldErrors: fieldErrors);
      return null;
    }

    state = const LoginState(isSubmitting: true);

    SignInResult? result;
    LoginState next;
    try {
      result = await ref
          .read(authControllerProvider.notifier)
          .signIn(email: email, password: password);
      next = _stateFor(result);
    } on Object catch (error) {
      next = LoginState(message: ApiException.messageOf(error));
    }

    // Com o login feito, o redirect troca de tela, e o provider pode já ter sido descartado.
    if (ref.mounted) {
      state = next;
      if (next.retrySeconds != null) _startCountdown();
    }

    return result;
  }

  /// O usuário editou o [field]: o erro dele sai da tela, e o dos outros campos continua.
  void fieldChanged(SignInField field) {
    if (state.errorFor(field) == null) return;

    state = LoginState(fieldErrors: Map.unmodifiable({...state.fieldErrors}..remove(field)));
  }

  void _startCountdown() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Um segundo da contagem do 429. No fim dela, o aviso sai e o "Entrar" volta sozinho (RM04).
  void _tick() {
    final seconds = (state.retrySeconds ?? 0) - 1;
    if (seconds > 0) {
      state = _rateLimited(seconds, announce: false);
      return;
    }

    _countdown?.cancel();
    _countdown = null;
    state = const LoginState();
  }
}

/// O estado de cada resultado do login: a tela inicial com o [SignInSuccess], o erro embaixo de
/// cada campo no [SignInFieldError] e, nos outros, o aviso geral (RM02 a RM04).
LoginState _stateFor(SignInResult result) => switch (result) {
  SignInSuccess() => const LoginState(),
  // A mesma para a senha errada e para a conta inexistente, inativa ou excluída (RM02).
  SignInWrongCredentials() => const LoginState(message: LoginViewModel.wrongCredentialsMessage),
  SignInFieldError(:final errors) => LoginState(fieldErrors: errors),
  // A mensagem da API, sem contagem: a API não informa quanto falta (RM03).
  SignInLocked(:final message) => LoginState(message: message),
  // Arredonda para cima: o "Entrar" não volta antes de a API aceitar de novo. O `Retry-After: 0`
  // ainda mostra o aviso por um segundo.
  SignInRateLimited(:final retryAfter) => _rateLimited(
    math.max(1, (retryAfter.inMilliseconds / Duration.millisecondsPerSecond).ceil()),
  ),
};

/// A contagem do limite por IP (RM04), com os [seconds] que faltam.
LoginState _rateLimited(int seconds, {bool announce = true}) => LoginState(
  message: 'Muitas tentativas. Tente de novo em $seconds s.',
  retrySeconds: seconds,
  announceMessage: announce,
);
