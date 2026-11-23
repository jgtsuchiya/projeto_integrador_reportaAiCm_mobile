import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/presentation/view_models/forgot_password_view_model.dart';

import '../../../../support/auth_fakes.dart';

const _email = 'maria.silva@exemplo.com';

void main() {
  group('ForgotPasswordViewModel', () {
    late AuthFakes fakes;
    late ProviderContainer container;
    late ProviderSubscription<ForgotPasswordState> screen;

    /// Abre a tela. O provider é autoDispose, e o ouvinte ([screen]) o mantém vivo entre as
    /// leituras, como a tela aberta.
    setUp(() {
      fakes = AuthFakes();
      container = ProviderContainer.test(overrides: fakes.overrides, retry: noAutomaticRetry);
      screen = container.listen(forgotPasswordViewModelProvider, (_, _) {});
    });

    ForgotPasswordViewModel sut() => container.read(forgotPasswordViewModelProvider.notifier);
    ForgotPasswordState state() => container.read(forgotPasswordViewModelProvider);

    test('deve começar sem o envio e com o botão ativo', () {
      expect(state(), const ForgotPasswordState());
      expect(state().wasSent, isFalse);
      expect(state().canSubmit, isTrue);
    });

    test('deve pedir o link e esperar 1 minuto para pedir de novo (RM13)', () {
      fakeAsync((async) {
        unawaited(sut().submit(' Maria.Silva@Exemplo.com '));
        async.flushMicrotasks();

        expect(fakes.auth.passwordResetCalls, [' Maria.Silva@Exemplo.com ']);
        expect(state(), const ForgotPasswordState(sentTo: _email, resendSeconds: 60));
        expect(state().wasSent, isTrue);
        expect(state().canSubmit, isFalse);

        async.elapse(const Duration(seconds: 59));

        expect(state().resendSeconds, 1);

        async.elapse(const Duration(seconds: 1));

        expect(state(), const ForgotPasswordState(sentTo: _email));
        expect(state().canSubmit, isTrue);
        expect(async.periodicTimerCount, 0);
      });
    });

    test('deve pedir de novo depois da espera, sem perder o envio anterior', () {
      fakeAsync((async) {
        unawaited(sut().submit(_email));
        async.elapse(const Duration(minutes: 1));

        unawaited(sut().submit(_email));
        async.flushMicrotasks();

        expect(fakes.auth.passwordResetCalls, hasLength(2));
        expect(state(), const ForgotPasswordState(sentTo: _email, resendSeconds: 60));

        async.elapse(const Duration(minutes: 1));
      });
    });

    test('deve ignorar o pedido durante a espera', () {
      fakeAsync((async) {
        unawaited(sut().submit(_email));
        async.flushMicrotasks();

        unawaited(sut().submit(_email));
        async.flushMicrotasks();

        expect(fakes.auth.passwordResetCalls, hasLength(1));
        async.elapse(const Duration(minutes: 1));
      });
    });

    test('deve ignorar o pedido durante o envio', () async {
      final pending = fakes.auth.passwordResetPending = Completer<void>();

      final first = sut().submit(_email);
      await sut().submit(_email);

      expect(state(), const ForgotPasswordState(isSubmitting: true));
      expect(fakes.auth.passwordResetCalls, hasLength(1));

      pending.complete();
      await first;
    });

    group('conferência antes de enviar', () {
      for (final (email, message) in [
        ('', 'Informe o e-mail.'),
        ('maria@exemplo', 'E-mail inválido.'),
      ]) {
        test('deve recusar "$email" sem chamar a API', () async {
          await sut().submit(email);

          expect(state(), ForgotPasswordState(emailError: message));
          expect(fakes.auth.passwordResetCalls, isEmpty);
        });
      }
    });

    group('respostas da API', () {
      test('deve mostrar a mensagem do e-mail do 400 no campo', () async {
        fakes.auth.passwordResetError = const ValidationException(
          fieldErrors: [FieldError(field: 'email', message: 'E-mail inválido.')],
        );

        await sut().submit(_email);

        expect(state(), const ForgotPasswordState(emailError: 'E-mail inválido.'));
      });

      test('deve mostrar a mensagem geral do 400 sem o campo', () async {
        fakes.auth.passwordResetError = const ValidationException(message: 'Dados inválidos.');

        await sut().submit(_email);

        expect(state().emailError, 'Dados inválidos.');
      });

      test('deve desativar o botão com a contagem do 429 e voltar sozinho', () {
        fakes.auth.passwordResetError = const RateLimitException(retryAfter: Duration(seconds: 2));

        fakeAsync((async) {
          unawaited(sut().submit(_email));
          async.flushMicrotasks();

          expect(
            state(),
            const ForgotPasswordState(
              message: 'Muitas tentativas. Tente de novo em 2 s.',
              retrySeconds: 2,
            ),
          );
          expect(state().canSubmit, isFalse);

          async.elapse(const Duration(seconds: 1));

          expect(
            state(),
            const ForgotPasswordState(
              message: 'Muitas tentativas. Tente de novo em 1 s.',
              retrySeconds: 1,
              announceMessage: false,
            ),
          );

          async.elapse(const Duration(seconds: 1));

          expect(state(), const ForgotPasswordState());
        });
      });

      test('deve esperar 1 minuto no 429 sem o Retry-After', () {
        fakes.auth.passwordResetError = const RateLimitException();

        fakeAsync((async) {
          unawaited(sut().submit(_email));
          async.flushMicrotasks();

          expect(state().retrySeconds, 60);
          async.elapse(const Duration(minutes: 1));
        });
      });

      for (final (description, error) in [
        ('sem conexão', const NetworkException()),
        ('com a API fora do ar', const ServerException(statusCode: 500)),
      ]) {
        test('deve mostrar a mensagem $description', () async {
          fakes.auth.passwordResetError = error;

          await sut().submit(_email);

          expect(state(), ForgotPasswordState(message: error.message));
        });
      }

      test('deve manter o envio anterior quando o pedido seguinte falha', () {
        fakeAsync((async) {
          unawaited(sut().submit(_email));
          async.elapse(const Duration(minutes: 1));
          fakes.auth.passwordResetError = const NetworkException();

          unawaited(sut().submit(_email));
          async.flushMicrotasks();

          expect(
            state(),
            const ForgotPasswordState(sentTo: _email, message: NetworkException.defaultMessage),
          );
        });
      });

      test('não deve mudar o estado quando a tela fecha durante o envio', () async {
        final pending = fakes.auth.passwordResetPending = Completer<void>();
        final request = sut().submit(_email);

        screen.close();
        await pumpEventQueue();
        pending.complete();

        await expectLater(request, completes);
      });
    });

    group('emailChanged', () {
      test('deve tirar o erro do campo', () async {
        await sut().submit('');

        sut().emailChanged('m');

        expect(state(), const ForgotPasswordState());
      });

      test('deve voltar a pedir o link, sem a espera, para outro e-mail', () {
        fakeAsync((async) {
          unawaited(sut().submit(_email));
          async.flushMicrotasks();

          sut().emailChanged('maria.silva@exemplo.co');

          expect(state(), const ForgotPasswordState());
          expect(state().canSubmit, isTrue);
          expect(async.periodicTimerCount, 0);
        });
      });

      test('deve manter a espera para o mesmo e-mail, com outra grafia', () {
        fakeAsync((async) {
          unawaited(sut().submit(_email));
          async.flushMicrotasks();

          sut().emailChanged(' Maria.Silva@Exemplo.com');

          expect(state(), const ForgotPasswordState(sentTo: _email, resendSeconds: 60));
          async.elapse(const Duration(minutes: 1));
        });
      });

      test('deve manter a contagem do 429, que é do IP', () {
        fakes.auth.passwordResetError = const RateLimitException(retryAfter: Duration(seconds: 5));

        fakeAsync((async) {
          unawaited(sut().submit(_email));
          async.flushMicrotasks();

          sut().emailChanged('outro@exemplo.com');

          expect(state().retrySeconds, 5);
          async.elapse(const Duration(seconds: 5));
        });
      });
    });

    test('deve parar a espera quando a tela fecha', () {
      fakeAsync((async) {
        unawaited(sut().submit(_email));
        async.flushMicrotasks();

        screen.close();
        // O Riverpod descarta o provider sem ouvintes num Future, depois das microtasks.
        async.elapse(Duration.zero);

        expect(async.periodicTimerCount, 0);
      });
    });

    test('deve descrever o estado no toString', () {
      expect(
        const ForgotPasswordState(sentTo: _email, resendSeconds: 3).toString(),
        allOf(contains('sentTo: $_email'), contains('resendSeconds: 3')),
      );
      expect(
        const ForgotPasswordState(sentTo: _email).hashCode,
        const ForgotPasswordState(sentTo: _email).hashCode,
      );
    });
  });
}
