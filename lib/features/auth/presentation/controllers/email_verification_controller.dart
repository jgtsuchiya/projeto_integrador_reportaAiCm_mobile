import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/core/utils/countdown.dart';
import 'package:reportaai_cm/features/auth/domain/models/email.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_profile.dart';
import 'package:reportaai_cm/features/profile/profile_providers.dart';

/// O reenvio do link de confirmação do e-mail (RM14). Não é `autoDispose`: a espera de 1 minuto
/// entre os envios vale para o app inteiro, na tela inicial e nas telas dos reportes, que mostram
/// o mesmo `EmailVerificationNotice`.
final NotifierProvider<EmailVerificationController, EmailVerificationState>
emailVerificationControllerProvider = NotifierProvider(EmailVerificationController.new);

/// O estado do reenvio para a conta do [email]: o envio em andamento, a espera até o próximo e o
/// resultado do último. O aviso de outra conta não usa este estado ([forAccount]).
@immutable
final class EmailVerificationState {
  const new({
    this.email,
    this.isSending = false,
    this.cooldownSeconds,
    this.feedback,
    this.isError = false,
  });

  /// A conta do último envio, como a API guarda o e-mail (RN02).
  final String? email;

  final bool isSending;

  /// Os segundos que faltam para o "Reenviar e-mail" voltar, depois do último envio. `null` fora
  /// da espera.
  final int? cooldownSeconds;

  /// O resultado do último reenvio, para o leitor de tela anunciar: o envio feito ou o erro.
  final String? feedback;

  /// Se o [feedback] é um erro.
  final bool isError;

  /// Se o "Reenviar e-mail" envia: nem durante o envio, nem durante a espera.
  bool get canResend => !isSending && cooldownSeconds == null;

  /// O estado para o aviso da conta de [accountEmail]: este, se é da mesma conta, ou o inicial.
  /// Assim, a espera do cadastro de uma conta não vale para outra que entrar depois.
  EmailVerificationState forAccount(String accountEmail) =>
      email == normalizeEmail(accountEmail) ? this : const EmailVerificationState();

  @override
  bool operator ==(Object other) =>
      other is EmailVerificationState &&
      other.email == email &&
      other.isSending == isSending &&
      other.cooldownSeconds == cooldownSeconds &&
      other.feedback == feedback &&
      other.isError == isError;

  @override
  int get hashCode => Object.hash(email, isSending, cooldownSeconds, feedback, isError);

  @override
  String toString() =>
      'EmailVerificationState(email: $email, isSending: $isSending, '
      'cooldownSeconds: $cooldownSeconds, feedback: $feedback, isError: $isError)';
}

/// Reenvia o link de confirmação do e-mail e controla a espera entre os envios: a API manda no
/// máximo um e-mail por minuto para a mesma conta, contando o do cadastro (RM14). Ao voltar para o
/// primeiro plano, atualiza o perfil, para o aviso sumir sozinho depois de o Client confirmar o
/// e-mail no navegador.
final class EmailVerificationController extends Notifier<EmailVerificationState> {
  /// A espera entre os envios, a mesma da API (`USER_TOKEN_RESEND_INTERVAL_MINUTES`).
  static const resendInterval = Duration(minutes: 1);

  /// O intervalo mínimo entre as atualizações do perfil ao voltar para o primeiro plano.
  static const resumeRefreshInterval = Duration(seconds: 30);

  static const sentMessage = 'Enviamos um novo link para o seu e-mail.';

  late final _countdown = Countdown(_tick);

  /// Enquanto ativo, o app não atualiza o perfil de novo ao voltar para o primeiro plano.
  Timer? _resumeRefreshPause;

  @override
  EmailVerificationState build() {
    ref.onDispose(() {
      _countdown.cancel();
      _resumeRefreshPause?.cancel();
    });
    return const EmailVerificationState();
  }

  /// A conta do [email] acabou de receber o link, no cadastro: o "Reenviar e-mail" espera 1
  /// minuto (RM14).
  void markSent(String email) {
    _startCooldown(EmailVerificationState(email: normalizeEmail(email)));
  }

  /// "Reenviar e-mail" (`POST /api/users/me/email-verification`). Ignorado sem o Client dentro,
  /// com o e-mail já confirmado, durante o envio e durante a espera.
  ///
  /// O 422 mostra a `message` da API (o e-mail já confirmado ou o último envio há menos de 1
  /// minuto) e atualiza o perfil, porque o e-mail pode ter sido confirmado no navegador.
  Future<void> resend() async {
    final profile = _unverifiedProfile;
    if (profile == null || !state.forAccount(profile.email).canResend) return;

    final email = normalizeEmail(profile.email);

    state = EmailVerificationState(email: email, isSending: true);

    try {
      await ref.read(profileRepositoryProvider).resendEmailVerification();
      if (!ref.mounted) return;

      _startCooldown(EmailVerificationState(email: email, feedback: sentMessage));
    } on BusinessRuleException catch (error) {
      if (!ref.mounted) return;

      state = EmailVerificationState(email: email, feedback: error.message, isError: true);
      await _refreshProfileQuietly();
    } on Object catch (error) {
      if (ref.mounted) {
        state = EmailVerificationState(
          email: email,
          feedback: ApiException.messageOf(error),
          isError: true,
        );
      }
    }
  }

  /// O app voltou para o primeiro plano: com o e-mail ainda não confirmado, atualiza o perfil, no
  /// máximo uma vez a cada 30 s (RM14). Uma falha não aparece na tela: o "puxar para atualizar"
  /// continua mostrando os erros.
  Future<void> refreshOnResume() async {
    if (_unverifiedProfile == null || (_resumeRefreshPause?.isActive ?? false)) return;

    _resumeRefreshPause = Timer(resumeRefreshInterval, () {});
    await _refreshProfileQuietly();
  }

  /// O perfil do Client logado, enquanto o e-mail não foi confirmado.
  UserProfile? get _unverifiedProfile => switch (ref.read(authControllerProvider)) {
    AuthAuthenticated(:final profile) when profile.emailVerifiedAt == null => profile,
    _ => null,
  };

  Future<void> _refreshProfileQuietly() async {
    try {
      await ref.read(authControllerProvider.notifier).refreshProfile();
    } on Object {
      // Sem rede ou com a API fora do ar, o aviso continua, e a próxima volta tenta de novo.
    }
  }

  void _startCooldown(EmailVerificationState next) {
    final seconds = resendInterval.inSeconds;
    state = EmailVerificationState(
      email: next.email,
      cooldownSeconds: seconds,
      feedback: next.feedback,
    );
    _countdown.start(seconds);
  }

  /// Um segundo da espera. No fim dela, o "Reenviar e-mail" volta, e o aviso do envio sai.
  void _tick(int secondsLeft) {
    state = secondsLeft > 0
        ? EmailVerificationState(
            email: state.email,
            cooldownSeconds: secondsLeft,
            feedback: state.feedback,
          )
        : EmailVerificationState(email: state.email);
  }
}
