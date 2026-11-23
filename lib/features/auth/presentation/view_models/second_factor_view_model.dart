import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/core/utils/countdown.dart';
import 'package:reportaai_cm/features/auth/auth_providers.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';

/// Estado da tela do código da segunda etapa: a conferência em andamento, o erro do código, os
/// avisos, a espera para pedir outro código e os erros seguidos do código atual.
final NotifierProvider<SecondFactorViewModel, SecondFactorState> secondFactorViewModelProvider =
    NotifierProvider.autoDispose(SecondFactorViewModel.new);

@immutable
final class SecondFactorState {
  const new({
    this.isSubmitting = false,
    this.isResending = false,
    this.codeError,
    this.message,
    this.notice,
    this.resendSeconds,
    this.failedAttempts = 0,
  });

  final bool isSubmitting;
  final bool isResending;

  /// O erro embaixo do campo: o código fora do formato ou o recusado pela API.
  final String? codeError;

  /// O aviso de erro acima do "Confirmar", como sem conexão ou o pedido de outro código recusado.
  final String? message;

  /// O aviso de que o código novo foi enviado.
  final String? notice;

  /// Os segundos que faltam para o "Enviar outro código" voltar. `null` fora da espera.
  final int? resendSeconds;

  /// Os erros seguidos do código atual. A API invalida o código no 5º, e a tela orienta a pedir
  /// outro.
  final int failedAttempts;

  /// Se o código atual já foi invalidado pelos erros seguidos (RN25).
  bool get isCodeInvalidated => failedAttempts >= SecondFactorViewModel.maxFailedAttempts;

  /// Se o "Enviar outro código" envia: nem durante um envio, nem durante a espera.
  bool get canResend => !isResending && resendSeconds == null;

  @override
  bool operator ==(Object other) =>
      other is SecondFactorState &&
      other.isSubmitting == isSubmitting &&
      other.isResending == isResending &&
      other.codeError == codeError &&
      other.message == message &&
      other.notice == notice &&
      other.resendSeconds == resendSeconds &&
      other.failedAttempts == failedAttempts;

  @override
  int get hashCode => Object.hash(
    isSubmitting,
    isResending,
    codeError,
    message,
    notice,
    resendSeconds,
    failedAttempts,
  );

  @override
  String toString() =>
      'SecondFactorState(isSubmitting: $isSubmitting, isResending: $isResending, '
      'codeError: $codeError, message: $message, notice: $notice, '
      'resendSeconds: $resendSeconds, failedAttempts: $failedAttempts)';
}

/// Confere o código da segunda etapa pelo `AuthController` e pede outro código (RM18). Quem leva
/// à tela inicial depois do código certo é o redirect das rotas.
///
/// O "Enviar outro código" começa desativado por 1 minuto: o login acabou de mandar um código, e a
/// API manda no máximo um por minuto para a mesma conta.
final class SecondFactorViewModel extends Notifier<SecondFactorState> {
  /// O tamanho do código, o mesmo da API (`LOGIN_CODE_LENGTH`).
  static const codeLength = 6;

  /// Os erros seguidos que invalidam o código, como na API.
  static const maxFailedAttempts = 5;

  /// A espera entre os envios do código, a mesma da API.
  static const resendInterval = Duration(minutes: 1);

  static const codeMissingMessage = 'Informe o código de $codeLength dígitos.';

  /// A mesma mensagem da API para o código fora do formato.
  static const codeFormatMessage = 'O código tem $codeLength dígitos.';

  static const sentMessage = 'Enviamos um novo código para o seu e-mail.';

  static const invalidatedMessage =
      'Depois de $maxFailedAttempts tentativas erradas, este código deixou de valer. Peça outro '
      'código.';

  static final _codePattern = RegExp('^\\d{$codeLength}\$');

  late final _countdown = Countdown(_tick);

  @override
  SecondFactorState build() {
    ref.onDispose(_countdown.cancel);
    _countdown.start(resendInterval.inSeconds);
    return SecondFactorState(resendSeconds: resendInterval.inSeconds);
  }

  /// "Confirmar": confere o formato e manda o [code] pelo `AuthController`. Com o código certo,
  /// o estado de login muda, e o redirect sai desta tela. Um envio durante outro é ignorado.
  Future<void> submit(String code) async {
    if (state.isSubmitting) return;

    final value = code.trim();
    final formatError = switch (value) {
      '' => codeMissingMessage,
      _ when !_codePattern.hasMatch(value) => codeFormatMessage,
      _ => null,
    };
    if (formatError != null) {
      state = _next(codeError: formatError);
      return;
    }

    state = _next(isSubmitting: true);

    Object? failure;
    try {
      await ref.read(authControllerProvider.notifier).verifySecondFactor(value);
    } on Object catch (error) {
      failure = error;
    }

    // A tela fecha quando o código certo leva à tela inicial.
    if (!ref.mounted) return;

    state = switch (failure) {
      null => _next(),
      // Código errado, vencido, já usado ou invalidado: a API dá a mesma mensagem nos quatro casos.
      BusinessRuleException(field: 'code', :final message) => _next(
        codeError: message,
        failedAttempts: state.failedAttempts + 1,
      ),
      // Sem o campo, é outra regra, como a sessão que já não está pendente.
      BusinessRuleException(:final message) => _next(message: message),
      final ValidationException error => _next(
        codeError: error.messageFor('code') ?? error.message,
      ),
      final error => _next(message: ApiException.messageOf(error)),
    };
  }

  /// "Enviar outro código": o novo invalida o anterior, e os erros seguidos voltam a zero. Ignorado
  /// durante um envio e durante a espera.
  Future<void> resend() async {
    if (!state.canResend) return;

    state = _next(isResending: true);

    Object? failure;
    try {
      await ref.read(authRepositoryProvider).resendLoginCode();
    } on Object catch (error) {
      failure = error;
    }

    if (!ref.mounted) return;

    final next = switch (failure) {
      null => SecondFactorState(notice: sentMessage, resendSeconds: resendInterval.inSeconds),
      // O último código saiu há menos de 1 minuto: o botão espera de novo.
      BusinessRuleException(:final message) => _next(
        message: message,
        resendSeconds: resendInterval.inSeconds,
      ),
      final error => _next(message: ApiException.messageOf(error)),
    };
    state = next;
    if (next.resendSeconds case final seconds?) _countdown.start(seconds);
  }

  /// O usuário editou o código: o erro do campo e os avisos saem. Os erros seguidos continuam.
  void codeChanged() {
    if (state.codeError == null && state.message == null && state.notice == null) return;

    state = _next();
  }

  /// O estado seguinte, com a espera e os erros seguidos de agora, sem os avisos e o erro do
  /// campo, a não ser os passados.
  SecondFactorState _next({
    bool isSubmitting = false,
    bool isResending = false,
    String? codeError,
    String? message,
    int? resendSeconds,
    int? failedAttempts,
  }) => SecondFactorState(
    isSubmitting: isSubmitting,
    isResending: isResending,
    codeError: codeError,
    message: message,
    resendSeconds: resendSeconds ?? state.resendSeconds,
    failedAttempts: failedAttempts ?? state.failedAttempts,
  );

  /// Um segundo da espera do "Enviar outro código". No fim dela, o botão volta, e o aviso do envio
  /// sai.
  void _tick(int secondsLeft) {
    state = SecondFactorState(
      isSubmitting: state.isSubmitting,
      codeError: state.codeError,
      message: state.message,
      notice: secondsLeft > 0 ? state.notice : null,
      resendSeconds: secondsLeft > 0 ? secondsLeft : null,
      failedAttempts: state.failedAttempts,
    );
  }
}
