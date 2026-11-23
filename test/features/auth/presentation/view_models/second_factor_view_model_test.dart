import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/view_models/second_factor_view_model.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';

const _wrongCode = BusinessRuleException(message: 'Código inválido ou expirado.', field: 'code');

void main() {
  group('SecondFactorViewModel', () {
    late AuthFakes fakes;
    late ProviderContainer container;

    /// Abre o app com a sessão pendente e a tela do código.
    void open() {
      fakes = AuthFakes(signedIn: true);
      fakes.session.secondFactorPending = true;
      container = ProviderContainer.test(overrides: fakes.overrides, retry: noAutomaticRetry)
        ..listen(authControllerProvider, (_, _) {})
        ..listen(secondFactorViewModelProvider, (_, _) {});
    }

    SecondFactorViewModel sut() => container.read(secondFactorViewModelProvider.notifier);
    SecondFactorState state() => container.read(secondFactorViewModelProvider);
    AuthState auth() => container.read(authControllerProvider);

    test('deve começar com o "Enviar outro código" esperando 1 minuto', () {
      fakeAsync((async) {
        open();
        async.flushMicrotasks();

        expect(state(), const SecondFactorState(resendSeconds: 60));
        expect(state().canResend, isFalse);

        async.elapse(const Duration(seconds: 60));

        expect(state(), const SecondFactorState());
        expect(state().canResend, isTrue);
      });
    });

    test('deve concluir o login com o código certo, sem os espaços (RM18)', () {
      fakeAsync((async) {
        open();
        async.flushMicrotasks();

        unawaited(sut().submit(' 042137 '));
        async.flushMicrotasks();

        expect(fakes.auth.verifyLoginCodeCalls, ['042137']);
        expect(auth(), AuthAuthenticated(clientProfile));
        expect(state().isSubmitting, isFalse);
      });
    });

    for (final (code, message) in [
      ('', SecondFactorViewModel.codeMissingMessage),
      ('  ', SecondFactorViewModel.codeMissingMessage),
      ('12345', SecondFactorViewModel.codeFormatMessage),
      ('12345a', SecondFactorViewModel.codeFormatMessage),
    ]) {
      test('deve recusar "$code" sem chamar a API', () {
        fakeAsync((async) {
          open();
          async.flushMicrotasks();

          unawaited(sut().submit(code));
          async.flushMicrotasks();

          expect(state().codeError, message);
          expect(fakes.auth.verifyLoginCodeCalls, isEmpty);
        });
      });
    }

    test('deve mostrar a mensagem da API no código errado e contar o erro', () {
      fakeAsync((async) {
        open();
        async.flushMicrotasks();
        fakes.auth.verifyLoginCodeError = _wrongCode;

        unawaited(sut().submit('000000'));
        async.flushMicrotasks();

        expect(state().codeError, 'Código inválido ou expirado.');
        expect(state().failedAttempts, 1);
        expect(state().isCodeInvalidated, isFalse);
        expect(auth(), const AuthSecondFactorPending());
      });
    });

    test('deve orientar a pedir outro código depois do 5º erro (RN25)', () {
      fakeAsync((async) {
        open();
        async.flushMicrotasks();
        fakes.auth.verifyLoginCodeError = _wrongCode;

        for (var attempt = 1; attempt <= 5; attempt++) {
          unawaited(sut().submit('000000'));
          async.flushMicrotasks();
          expect(state().isCodeInvalidated, attempt == 5, reason: 'tentativa $attempt');
        }
      });
    });

    test('deve zerar os erros e esperar de novo depois de pedir outro código', () {
      fakeAsync((async) {
        open();
        async.flushMicrotasks();
        fakes.auth.verifyLoginCodeError = _wrongCode;
        for (var attempt = 0; attempt < 5; attempt++) {
          unawaited(sut().submit('000000'));
          async.flushMicrotasks();
        }
        async.elapse(SecondFactorViewModel.resendInterval);

        unawaited(sut().resend());
        async.flushMicrotasks();

        expect(fakes.auth.resendLoginCodeCalls, 1);
        expect(
          state(),
          const SecondFactorState(notice: SecondFactorViewModel.sentMessage, resendSeconds: 60),
        );

        async.elapse(SecondFactorViewModel.resendInterval);

        expect(state(), const SecondFactorState(), reason: 'O aviso sai no fim da espera.');
      });
    });

    test('deve ignorar o "Enviar outro código" durante a espera', () {
      fakeAsync((async) {
        open();
        async.flushMicrotasks();

        unawaited(sut().resend());
        async.flushMicrotasks();

        expect(fakes.auth.resendLoginCodeCalls, 0);
      });
    });

    test('deve mostrar a mensagem do 422 do reenvio e esperar de novo', () {
      fakeAsync((async) {
        open();
        async.elapse(SecondFactorViewModel.resendInterval);
        fakes.auth.resendLoginCodeError = const BusinessRuleException(
          message: 'Um e-mail acabou de ser enviado. Aguarde um minuto para pedir outro.',
        );

        unawaited(sut().resend());
        async.flushMicrotasks();

        expect(state().message, startsWith('Um e-mail acabou de ser enviado.'));
        expect(state().resendSeconds, 60);
      });
    });

    test('deve mostrar o erro do reenvio sem conexão, com o botão de volta', () {
      fakeAsync((async) {
        open();
        async.elapse(SecondFactorViewModel.resendInterval);
        fakes.auth.resendLoginCodeError = const NetworkException();

        unawaited(sut().resend());
        async.flushMicrotasks();

        expect(state().message, NetworkException.defaultMessage);
        expect(state().canResend, isTrue);
      });
    });

    for (final (description, error, codeError, message) in [
      (
        'o 400 do código fora do formato',
        const ValidationException(
          fieldErrors: [FieldError(field: 'code', message: 'O código tem 6 dígitos.')],
        ),
        'O código tem 6 dígitos.',
        null,
      ),
      (
        'a sessão que já não está pendente',
        const BusinessRuleException(message: 'Sem etapa.'),
        null,
        'Sem etapa.',
      ),
      ('sem conexão', const NetworkException(), null, NetworkException.defaultMessage),
    ]) {
      test('deve mostrar $description', () {
        fakeAsync((async) {
          open();
          async.flushMicrotasks();
          fakes.auth.verifyLoginCodeError = error;

          unawaited(sut().submit('042137'));
          async.flushMicrotasks();

          expect(state().codeError, codeError);
          expect(state().message, message);
          expect(state().failedAttempts, 0);
        });
      });
    }

    test('deve ignorar o "Confirmar" durante a conferência', () {
      fakeAsync((async) {
        open();
        async.flushMicrotasks();
        final pending = fakes.auth.verifyLoginCodePending = Completer<void>();

        unawaited(sut().submit('042137'));
        async.flushMicrotasks();
        expect(state().isSubmitting, isTrue);
        unawaited(sut().submit('042137'));
        async.flushMicrotasks();

        expect(fakes.auth.verifyLoginCodeCalls, hasLength(1));
        pending.complete();
        async.flushMicrotasks();
      });
    });

    test('deve tirar o erro do campo quando o código muda, mantendo os erros seguidos', () {
      fakeAsync((async) {
        open();
        async.flushMicrotasks();
        fakes.auth.verifyLoginCodeError = _wrongCode;
        unawaited(sut().submit('000000'));
        async.flushMicrotasks();

        sut().codeChanged();

        expect(state().codeError, isNull);
        expect(state().failedAttempts, 1);
        expect(state().resendSeconds, isNotNull);

        final before = state();
        sut().codeChanged();
        expect(state(), same(before), reason: 'Sem erro, nada muda.');
      });
    });

    test('deve comparar o estado pelo valor', () {
      const state = SecondFactorState(codeError: 'erro', failedAttempts: 2);

      expect(state, const SecondFactorState(codeError: 'erro', failedAttempts: 2));
      expect(
        state.hashCode,
        const SecondFactorState(codeError: 'erro', failedAttempts: 2).hashCode,
      );
      expect(state.toString(), contains('failedAttempts: 2'));
    });
  });
}
