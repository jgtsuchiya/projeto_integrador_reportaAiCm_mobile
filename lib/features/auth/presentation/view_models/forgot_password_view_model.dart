import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/core/utils/countdown.dart';
import 'package:reportaai_cm/features/auth/auth_providers.dart';
import 'package:reportaai_cm/features/auth/domain/models/email.dart';

/// Estado da tela "Esqueci minha senha": o envio em andamento, o erro do e-mail, se o link já foi
/// pedido e as esperas para pedir de novo.
final NotifierProvider<ForgotPasswordViewModel, ForgotPasswordState>
forgotPasswordViewModelProvider = NotifierProvider.autoDispose(ForgotPasswordViewModel.new);

@immutable
final class ForgotPasswordState {
  const new({
    this.isSubmitting = false,
    this.emailError,
    this.message,
    this.sentTo,
    this.resendSeconds,
    this.retrySeconds,
    this.announceMessage = true,
  });

  final bool isSubmitting;

  /// O erro embaixo do campo de e-mail, da conferência antes de enviar ou do 400 da API.
  final String? emailError;

  /// O aviso geral, acima do botão: sem conexão ou a contagem do limite por IP.
  final String? message;

  /// O e-mail do último pedido que a API recebeu (204), como ela o guarda (RN02). `null` antes
  /// do primeiro.
  final String? sentTo;

  /// Os segundos que faltam para o "Enviar de novo" voltar, depois de um pedido (RM13).
  final int? resendSeconds;

  /// Na contagem regressiva do limite por IP, os segundos que faltam para o botão voltar.
  final int? retrySeconds;

  /// Se o leitor de tela anuncia o [message]. Na contagem do 429, só quando ela começa.
  final bool announceMessage;

  /// Se o link já foi pedido: a tela mostra a mensagem do envio e o "Voltar ao login".
  bool get wasSent => sentTo != null;

  /// Se o botão envia: nem durante o envio, nem durante as esperas.
  bool get canSubmit => !isSubmitting && resendSeconds == null && retrySeconds == null;

  @override
  bool operator ==(Object other) =>
      other is ForgotPasswordState &&
      other.isSubmitting == isSubmitting &&
      other.emailError == emailError &&
      other.message == message &&
      other.sentTo == sentTo &&
      other.resendSeconds == resendSeconds &&
      other.retrySeconds == retrySeconds &&
      other.announceMessage == announceMessage;

  @override
  int get hashCode => Object.hash(
    isSubmitting,
    emailError,
    message,
    sentTo,
    resendSeconds,
    retrySeconds,
    announceMessage,
  );

  @override
  String toString() =>
      'ForgotPasswordState(isSubmitting: $isSubmitting, emailError: $emailError, '
      'message: $message, sentTo: $sentTo, resendSeconds: $resendSeconds, '
      'retrySeconds: $retrySeconds, announceMessage: $announceMessage)';
}

/// Pede o link para criar uma senha nova (RM13). A mensagem depois do pedido é sempre a mesma,
/// com ou sem conta (RN20), e o "Enviar de novo" espera 1 minuto: a API manda no máximo um e-mail
/// por minuto para a mesma conta.
final class ForgotPasswordViewModel extends Notifier<ForgotPasswordState> {
  static const sentMessage =
      'Se este e-mail tiver uma conta, você vai receber um link para criar uma senha nova. O link '
      'vale por 60 minutos.';

  /// A espera entre os pedidos, a mesma da API para a mesma conta.
  static const resendInterval = Duration(minutes: 1);

  late final _countdown = Countdown(_tick);

  @override
  ForgotPasswordState build() {
    ref.onDispose(_countdown.cancel);
    return const ForgotPasswordState();
  }

  /// Pede o link para o [email], depois de conferir o formato: com o e-mail recusado, a API não é
  /// chamada. Um pedido durante outro, ou durante as esperas, é ignorado.
  Future<void> submit(String email) async {
    if (!state.canSubmit) return;

    final sentTo = state.sentTo;
    if (validateEmail(email) case final error?) {
      state = ForgotPasswordState(sentTo: sentTo, emailError: error);
      return;
    }

    state = ForgotPasswordState(sentTo: sentTo, isSubmitting: true);

    ForgotPasswordState next;
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(email);
      next = ForgotPasswordState(
        sentTo: normalizeEmail(email),
        resendSeconds: resendInterval.inSeconds,
      );
    } on ValidationException catch (error) {
      next = ForgotPasswordState(
        sentTo: sentTo,
        emailError: error.messageFor('email') ?? error.message,
      );
    } on RateLimitException catch (error) {
      next = _rateLimited(countdownSecondsOf(error.retryAfter ?? resendInterval), sentTo: sentTo);
    } on Object catch (error) {
      next = ForgotPasswordState(sentTo: sentTo, message: ApiException.messageOf(error));
    }

    // A tela pode ter fechado enquanto o pedido esperava a API.
    if (!ref.mounted) return;

    state = next;
    if (next.resendSeconds case final seconds?) _countdown.start(seconds);
    if (next.retrySeconds case final seconds?) _countdown.start(seconds);
  }

  /// O usuário editou o e-mail: o erro do campo sai. Um e-mail diferente do último pedido é outra
  /// conta, e o botão volta a pedir o link, sem a espera do pedido anterior. A contagem do 429
  /// continua: o limite é do IP.
  void emailChanged(String email) {
    if (state.retrySeconds != null || state.isSubmitting) return;

    final isOtherAccount = state.wasSent && normalizeEmail(email) != state.sentTo;
    if (isOtherAccount) {
      _countdown.cancel();
      state = const ForgotPasswordState();
    } else if (state.emailError != null) {
      state = ForgotPasswordState(
        sentTo: state.sentTo,
        resendSeconds: state.resendSeconds,
        message: state.message,
      );
    }
  }

  /// Um segundo da espera que estiver rodando: a do "Enviar de novo" ou a do 429.
  void _tick(int secondsLeft) {
    final seconds = secondsLeft > 0 ? secondsLeft : null;

    if (state.retrySeconds != null) {
      state = seconds == null
          ? ForgotPasswordState(sentTo: state.sentTo)
          : _rateLimited(seconds, sentTo: state.sentTo, announce: false);
    } else {
      state = ForgotPasswordState(sentTo: state.sentTo, resendSeconds: seconds);
    }
  }
}

/// A contagem do limite por IP, com os [seconds] que faltam.
ForgotPasswordState _rateLimited(int seconds, {required String? sentTo, bool announce = true}) =>
    ForgotPasswordState(
      sentTo: sentTo,
      message: 'Muitas tentativas. Tente de novo em $seconds s.',
      retrySeconds: seconds,
      announceMessage: announce,
    );
