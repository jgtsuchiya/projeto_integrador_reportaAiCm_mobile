import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/domain/models/sign_in_result.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/view_models/login_view_model.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';

const _email = 'maria.silva@exemplo.com';
const _password = 'SenhaSecreta123';

void main() {
  group('LoginViewModel', () {
    late AuthFakes fakes;
    late ProviderContainer container;

    /// Abre a tela de login, depois da abertura sem sessão. O provider é autoDispose, e o ouvinte
    /// o mantém vivo entre as leituras, como a tela aberta.
    setUp(() async {
      fakes = AuthFakes();
      container = ProviderContainer.test(overrides: fakes.overrides, retry: noAutomaticRetry)
        ..listen(authControllerProvider, (_, _) {})
        ..listen(loginViewModelProvider, (_, _) {});
      await pumpEventQueue();
    });

    LoginViewModel sut() => container.read(loginViewModelProvider.notifier);
    LoginState state() => container.read(loginViewModelProvider);

    Future<void> submit() => sut().submit(email: _email, password: _password);

    test('deve começar sem carregando e sem aviso', () {
      expect(state(), const LoginState());
    });

    test('deve entrar pelo AuthController, com o e-mail e a senha digitados', () async {
      await submit();

      expect(fakes.auth.signInCalls.single, (email: _email, password: _password));
      expect(container.read(authControllerProvider), AuthAuthenticated(clientProfile));
      expect(state(), const LoginState());
    });

    for (final (description, result, message) in [
      ('a senha errada (RM02)', const SignInWrongCredentials(), 'E-mail ou senha incorretos.'),
      (
        'o erro de campo',
        const SignInFieldError({
          SignInField.email: SignInFieldError.emailInvalidMessage,
          SignInField.password: SignInFieldError.passwordRequiredMessage,
        }),
        'E-mail inválido. Informe a senha.',
      ),
      (
        'o bloqueio por tentativas (RM03)',
        const SignInLocked('Muitas tentativas de login. Tente de novo em alguns minutos.'),
        'Muitas tentativas de login. Tente de novo em alguns minutos.',
      ),
      (
        'o limite por IP (RM04)',
        const SignInRateLimited(retryAfter: Duration(seconds: 30)),
        'Muitas tentativas. Tente de novo em 30 s.',
      ),
    ]) {
      test('deve mostrar o aviso para $description', () async {
        fakes.auth.signInResult = result;

        await submit();

        expect(state(), LoginState(message: message));
      });
    }

    for (final (description, error) in [
      ('sem conexão', const NetworkException()),
      ('com a API fora do ar', const ServerException(statusCode: 500)),
    ]) {
      test('deve mostrar a mensagem do erro $description', () async {
        fakes.auth.signInError = error;

        await submit();

        expect(state(), LoginState(message: error.message));
      });
    }

    test('deve mostrar o carregando e ignorar um segundo envio no meio', () async {
      final pending = fakes.auth.signInPending = Completer<SignInResult>();

      final first = submit();
      await submit();

      expect(state(), const LoginState(isSubmitting: true));
      expect(fakes.auth.signInCalls, hasLength(1));

      pending.complete(const SignInWrongCredentials());
      await first;

      expect(state().isSubmitting, isFalse);
    });

    test('deve tirar o aviso anterior ao enviar de novo', () async {
      fakes.auth.signInResult = const SignInWrongCredentials();
      await submit();
      final pending = fakes.auth.signInPending = Completer<SignInResult>();

      final second = submit();

      expect(state(), const LoginState(isSubmitting: true));

      pending.complete(const SignInSuccess());
      await second;
    });

    test('deve comparar o estado pelo valor', () {
      expect(const LoginState(message: 'a'), const LoginState(message: 'a'));
      expect(const LoginState(message: 'a').hashCode, const LoginState(message: 'a').hashCode);
      expect(const LoginState(isSubmitting: true), isNot(const LoginState()));
      expect(
        const LoginState(message: 'Aviso').toString(),
        'LoginState(isSubmitting: false, message: Aviso)',
      );
    });
  });
}
