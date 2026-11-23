import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/email_verification_controller.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';

const _email = 'maria.silva@exemplo.com';

void main() {
  group('EmailVerificationController', () {
    late AuthFakes fakes;
    late ProviderContainer container;

    final verifiedProfile = clientProfileWith(emailVerifiedAt: DateTime.utc(2026, 10, 5, 12));

    /// O Client já dentro, com o e-mail ainda não confirmado (o do exemplo).
    setUp(() async {
      fakes = AuthFakes(signedIn: true);
      container = ProviderContainer.test(overrides: fakes.overrides, retry: noAutomaticRetry)
        ..listen(authControllerProvider, (_, _) {})
        ..listen(emailVerificationControllerProvider, (_, _) {});
      await pumpEventQueue();
    });

    EmailVerificationController sut() =>
        container.read(emailVerificationControllerProvider.notifier);
    EmailVerificationState state() => container.read(emailVerificationControllerProvider);

    test('deve começar sem envio e sem espera', () {
      expect(state(), const EmailVerificationState());
      expect(state().canResend, isTrue);
    });

    group('markSent', () {
      test('deve esperar 1 minuto depois do cadastro e voltar sozinho (RM14)', () {
        fakeAsync((async) {
          sut().markSent(' Maria.Silva@Exemplo.com ');

          expect(state(), const EmailVerificationState(email: _email, cooldownSeconds: 60));
          expect(state().canResend, isFalse);

          async.elapse(const Duration(seconds: 59));

          expect(state().cooldownSeconds, 1);

          async.elapse(const Duration(seconds: 1));

          expect(state(), const EmailVerificationState(email: _email));
          expect(state().canResend, isTrue);
          expect(async.periodicTimerCount, 0);
        });
      });
    });

    group('resend', () {
      test('deve reenviar o link, avisar e esperar 1 minuto para o próximo (RM14)', () {
        fakeAsync((async) {
          unawaited(sut().resend());
          async.flushMicrotasks();

          expect(fakes.profile.resendCalls, 1);
          expect(
            state(),
            const EmailVerificationState(
              email: _email,
              cooldownSeconds: 60,
              feedback: EmailVerificationController.sentMessage,
            ),
          );

          async.elapse(const Duration(minutes: 1));

          // No fim da espera, o aviso do envio sai.
          expect(state(), const EmailVerificationState(email: _email));
        });
      });

      test('deve mostrar o "Enviando" durante o reenvio e ignorar outro toque', () async {
        final pending = fakes.profile.resendPending = Completer<void>();

        final first = sut().resend();
        await sut().resend();

        expect(state(), const EmailVerificationState(email: _email, isSending: true));
        expect(fakes.profile.resendCalls, 1);

        pending.complete();
        await first;
      });

      test('deve ignorar o reenvio durante a espera do cadastro', () {
        fakeAsync((async) {
          sut().markSent(_email);

          unawaited(sut().resend());
          async.flushMicrotasks();

          expect(fakes.profile.resendCalls, 0);
          async.elapse(const Duration(minutes: 1));
        });
      });

      test('deve mostrar a message do 422 e atualizar o perfil', () async {
        const message = 'O e-mail desta conta já foi verificado.';
        fakes.profile.resendError = const BusinessRuleException(message: message);
        fakes.profile.result = verifiedProfile;

        await sut().resend();

        expect(
          state(),
          const EmailVerificationState(email: _email, feedback: message, isError: true),
        );
        // O e-mail já tinha sido confirmado no navegador: o perfil novo tira o aviso.
        expect(container.read(authControllerProvider), AuthAuthenticated(verifiedProfile));
      });

      test('não deve mostrar erro quando a atualização depois do 422 falha', () async {
        const message = 'Um e-mail acabou de ser enviado. Aguarde um minuto para pedir outro.';
        fakes.profile.resendError = const BusinessRuleException(message: message);
        fakes.profile.error = const NetworkException();

        await sut().resend();

        expect(state().feedback, message);
        expect(container.read(authControllerProvider), AuthAuthenticated(clientProfile));
      });

      for (final (description, error) in [
        ('sem conexão', const NetworkException()),
        ('com a API fora do ar', const ServerException(statusCode: 500)),
      ]) {
        test('deve mostrar a mensagem $description, sem a espera', () async {
          fakes.profile.resendError = error;

          await sut().resend();

          expect(
            state(),
            EmailVerificationState(email: _email, feedback: error.message, isError: true),
          );
          expect(state().canResend, isTrue);
        });
      }

      test('deve ignorar o reenvio com o e-mail já confirmado', () async {
        fakes.profile.result = verifiedProfile;
        await container.read(authControllerProvider.notifier).refreshProfile();

        await sut().resend();

        expect(fakes.profile.resendCalls, 0);
      });

      test('deve ignorar o reenvio sem o Client dentro', () async {
        await container.read(authControllerProvider.notifier).signOut();

        await sut().resend();

        expect(fakes.profile.resendCalls, 0);
      });
    });

    group('refreshOnResume', () {
      test('deve atualizar o perfil e tirar o aviso do e-mail confirmado (RM14)', () async {
        fakes.profile.result = verifiedProfile;

        await sut().refreshOnResume();

        expect(fakes.profile.calls, 2);
        expect(container.read(authControllerProvider), AuthAuthenticated(verifiedProfile));
      });

      test('deve atualizar no máximo uma vez a cada 30 s', () {
        fakeAsync((async) {
          unawaited(sut().refreshOnResume());
          async.flushMicrotasks();
          unawaited(sut().refreshOnResume());
          async.flushMicrotasks();

          expect(fakes.profile.calls, 2);

          async.elapse(const Duration(seconds: 29));
          unawaited(sut().refreshOnResume());
          async.flushMicrotasks();

          expect(fakes.profile.calls, 2);

          async.elapse(const Duration(seconds: 1));
          unawaited(sut().refreshOnResume());
          async.flushMicrotasks();

          expect(fakes.profile.calls, 3);
          async.elapse(const Duration(seconds: 30));
        });
      });

      test('não deve mostrar erro nem tirar o perfil quando a atualização falha', () async {
        fakes.profile.error = const NetworkException();

        await expectLater(sut().refreshOnResume(), completes);

        expect(container.read(authControllerProvider), AuthAuthenticated(clientProfile));
        expect(state(), const EmailVerificationState());
      });

      test('não deve atualizar com o e-mail já confirmado', () async {
        fakes.profile.result = verifiedProfile;
        await container.read(authControllerProvider.notifier).refreshProfile();

        await sut().refreshOnResume();

        expect(fakes.profile.calls, 2);
      });
    });

    group('EmailVerificationState', () {
      test('deve valer só para a conta do último envio', () {
        const state = EmailVerificationState(email: _email, cooldownSeconds: 30);

        expect(state.forAccount(' Maria.Silva@Exemplo.com'), same(state));
        expect(state.forAccount('outra@exemplo.com'), const EmailVerificationState());
      });

      test('deve comparar pelo valor e descrever o estado', () {
        const state = EmailVerificationState(email: _email, feedback: 'Enviado');

        expect(state, const EmailVerificationState(email: _email, feedback: 'Enviado'));
        expect(
          state.hashCode,
          const EmailVerificationState(email: _email, feedback: 'Enviado').hashCode,
        );
        expect(state.toString(), contains('feedback: Enviado'));
      });
    });
  });
}
