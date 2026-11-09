import 'dart:async';

import 'package:fake_async/fake_async.dart';
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

    Future<SignInResult?> submit({String email = _email, String password = _password}) =>
        sut().submit(email: email, password: password);

    test('deve começar sem carregando e sem aviso', () {
      expect(state(), const LoginState());
      expect(state().canSubmit, isTrue);
    });

    test('deve entrar pelo AuthController, com o e-mail e a senha digitados', () async {
      final result = await submit();

      expect(result, const SignInSuccess());
      expect(fakes.auth.signInCalls.single, (email: _email, password: _password));
      expect(container.read(authControllerProvider), AuthAuthenticated(clientProfile));
      expect(state(), const LoginState());
    });

    group('conferência antes de enviar (RM05)', () {
      test('deve pedir o e-mail e a senha, sem chamar a API', () async {
        final result = await submit(email: ' ', password: '');

        expect(result, isNull);
        expect(fakes.auth.signInCalls, isEmpty);
        expect(
          state(),
          const LoginState(
            fieldErrors: {
              SignInField.email: SignInFieldError.emailRequiredMessage,
              SignInField.password: SignInFieldError.passwordRequiredMessage,
            },
          ),
        );
      });

      test('deve recusar o e-mail fora do formato, sem chamar a API', () async {
        await submit(email: 'maria@exemplo');

        expect(fakes.auth.signInCalls, isEmpty);
        expect(state().errorFor(SignInField.email), SignInFieldError.emailInvalidMessage);
        expect(state().errorFor(SignInField.password), isNull);
      });

      test('deve manter o motivo de ter voltado ao login, que só sai num envio', () async {
        fakes.session.hasStoredSession = true;
        fakes.profile.error = const UnauthorizedException();
        container.invalidate(authControllerProvider);
        await pumpEventQueue();

        await submit(password: '');

        expect(
          container.read(authControllerProvider),
          const AuthUnauthenticated(reason: UnauthenticatedReason.sessionExpired),
        );
      });
    });

    for (final (description, result, message) in [
      ('a senha errada (RM02)', const SignInWrongCredentials(), 'E-mail ou senha incorretos.'),
      (
        'o bloqueio por tentativas, com a mensagem da API (RM03)',
        const SignInLocked('Muitas tentativas de login. Tente de novo em alguns minutos.'),
        'Muitas tentativas de login. Tente de novo em alguns minutos.',
      ),
    ]) {
      test('deve mostrar o aviso para $description', () async {
        fakes.auth.signInResult = result;

        final returned = await submit();

        expect(returned, result);
        expect(state(), LoginState(message: message));
      });
    }

    test('deve mostrar o erro de cada campo do FIELD_ERROR, sem o aviso geral', () async {
      const errors = {
        SignInField.email: SignInFieldError.emailInvalidMessage,
        SignInField.password: SignInFieldError.passwordRequiredMessage,
      };
      fakes.auth.signInResult = const SignInFieldError(errors);

      await submit();

      expect(state(), const LoginState(fieldErrors: errors));
    });

    for (final (description, error) in [
      ('sem conexão', const NetworkException()),
      ('com a API fora do ar', const ServerException(statusCode: 500)),
    ]) {
      test('deve mostrar a mensagem do erro $description', () async {
        fakes.auth.signInError = error;

        final result = await submit();

        expect(result, isNull);
        expect(state(), LoginState(message: error.message));
      });
    }

    test('deve mostrar o carregando e ignorar um segundo envio no meio', () async {
      final pending = fakes.auth.signInPending = Completer<SignInResult>();

      final first = submit();
      final second = await submit();

      expect(second, isNull);
      expect(state(), const LoginState(isSubmitting: true));
      expect(state().canSubmit, isFalse);
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

    group('fieldChanged', () {
      test('deve tirar só o erro do campo editado', () async {
        await submit(email: '', password: '');

        sut().fieldChanged(SignInField.email);

        expect(
          state(),
          const LoginState(
            fieldErrors: {SignInField.password: SignInFieldError.passwordRequiredMessage},
          ),
        );
      });

      test('não deve mudar o estado quando o campo não tem erro', () async {
        fakes.auth.signInResult = const SignInWrongCredentials();
        await submit();
        final before = state();

        sut().fieldChanged(SignInField.email);

        expect(state(), same(before));
      });
    });

    group('contagem do limite por IP (RM04)', () {
      String messageFor(int seconds) => 'Muitas tentativas. Tente de novo em $seconds s.';

      test('deve desativar o "Entrar" com a contagem e voltar sozinho no fim dela', () {
        fakes.auth.signInResult = const SignInRateLimited(retryAfter: Duration(seconds: 3));

        fakeAsync((async) {
          unawaited(submit());
          async.flushMicrotasks();

          expect(state(), LoginState(message: messageFor(3), retrySeconds: 3));
          expect(state().canSubmit, isFalse);

          async.elapse(const Duration(seconds: 1));

          expect(
            state(),
            LoginState(message: messageFor(2), retrySeconds: 2, announceMessage: false),
          );

          async.elapse(const Duration(seconds: 2));

          expect(state(), const LoginState());
          expect(state().canSubmit, isTrue);
          expect(async.periodicTimerCount, 0);
        });
      });

      test('deve anunciar o aviso ao leitor de tela só quando a contagem começa', () {
        fakes.auth.signInResult = const SignInRateLimited(retryAfter: Duration(seconds: 3));

        fakeAsync((async) {
          unawaited(submit());
          async.flushMicrotasks();

          expect(state().announceMessage, isTrue);

          async.elapse(const Duration(seconds: 1));

          expect(state().announceMessage, isFalse);
        });
      });

      test('deve ignorar o envio durante a contagem', () {
        fakes.auth.signInResult = const SignInRateLimited(retryAfter: Duration(seconds: 3));

        fakeAsync((async) {
          unawaited(submit());
          async.flushMicrotasks();

          SignInResult? result = const SignInSuccess();
          unawaited(submit().then((value) => result = value));
          async.flushMicrotasks();

          expect(result, isNull);
          expect(fakes.auth.signInCalls, hasLength(1));
          expect(state().retrySeconds, 3);
        });
      });

      for (final (retryAfter, seconds) in [
        (Duration.zero, 1),
        (const Duration(milliseconds: 1500), 2),
        (SignInRateLimited.defaultRetryAfter, 60),
      ]) {
        test('deve contar $seconds s para o Retry-After de $retryAfter', () {
          fakes.auth.signInResult = SignInRateLimited(retryAfter: retryAfter);

          fakeAsync((async) {
            unawaited(submit());
            async.flushMicrotasks();

            expect(state().retrySeconds, seconds);
            expect(state().message, messageFor(seconds));

            async.elapse(Duration(seconds: seconds));

            expect(state(), const LoginState());
          });
        });
      }

      test('deve parar a contagem quando a tela fecha', () {
        fakes.auth.signInResult = const SignInRateLimited(retryAfter: Duration(seconds: 3));

        fakeAsync((async) {
          unawaited(submit());
          async.flushMicrotasks();
          expect(async.periodicTimerCount, 1);

          container.dispose();

          expect(async.periodicTimerCount, 0);
        });
      });
    });

    test('deve comparar o estado pelo valor', () {
      // Montado fora de um const, para não comparar a mesma instância.
      LoginState withError(SignInField field) => LoginState(fieldErrors: {field: 'Erro'});

      expect(const LoginState(message: 'a'), const LoginState(message: 'a'));
      expect(const LoginState(message: 'a').hashCode, const LoginState(message: 'a').hashCode);
      expect(const LoginState(isSubmitting: true), isNot(const LoginState()));
      expect(const LoginState(retrySeconds: 3), isNot(const LoginState(retrySeconds: 2)));
      expect(const LoginState(announceMessage: false), isNot(const LoginState()));
      expect(
        withError(SignInField.email),
        const LoginState(fieldErrors: {SignInField.email: 'Erro'}),
      );
      expect(
        withError(SignInField.email).hashCode,
        const LoginState(fieldErrors: {SignInField.email: 'Erro'}).hashCode,
      );
      expect(withError(SignInField.email), isNot(withError(SignInField.password)));
      expect(
        const LoginState(message: 'Aviso').toString(),
        'LoginState(isSubmitting: false, fieldErrors: {}, message: Aviso, retrySeconds: null, '
        'announceMessage: true)',
      );
    });
  });
}
