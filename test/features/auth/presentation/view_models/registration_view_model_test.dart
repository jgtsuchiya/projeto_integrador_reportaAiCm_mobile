import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/domain/models/client_registration.dart';
import 'package:reportaai_cm/features/auth/domain/models/registration_result.dart';
import 'package:reportaai_cm/features/auth/domain/models/sign_in_result.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/email_verification_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/view_models/registration_view_model.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';

const _email = 'maria.silva@exemplo.com';
const _password = 'senha-forte-1';

void main() {
  group('RegistrationViewModel', () {
    late AuthFakes fakes;
    late ProviderContainer container;
    late ProviderSubscription<RegistrationState> screen;

    /// Abre o cadastro, depois da abertura sem sessão. O provider é autoDispose, e o ouvinte
    /// ([screen]) o mantém vivo entre as leituras, como a tela aberta.
    setUp(() async {
      fakes = AuthFakes();
      container = ProviderContainer.test(overrides: fakes.overrides, retry: noAutomaticRetry)
        ..listen(authControllerProvider, (_, _) {});
      screen = container.listen(registrationViewModelProvider, (_, _) {});
      await pumpEventQueue();
    });

    RegistrationViewModel sut() => container.read(registrationViewModelProvider.notifier);
    RegistrationState state() => container.read(registrationViewModelProvider);

    /// Os campos como estão na tela, com as máscaras.
    Future<RegistrationOutcome?> submit({
      String name = ' Maria da Silva ',
      String email = _email,
      String password = _password,
      String cpf = '529.982.247-25',
      String phone = '(44) 99999-8888',
      String birthDate = '20/05/1990',
    }) => sut().submit(
      name: name,
      email: email,
      password: password,
      cpf: cpf,
      phone: phone,
      birthDate: birthDate,
    );

    test('deve começar sem carregando e sem aviso', () {
      expect(state(), const RegistrationState());
      expect(state().canSubmit, isTrue);
    });

    group('conta criada', () {
      test('deve enviar os campos no formato da API, sem as máscaras', () async {
        await submit();

        expect(
          fakes.registration.calls.single,
          const ClientRegistration(
            name: ' Maria da Silva ',
            email: _email,
            password: _password,
            cpf: '52998224725',
            phone: '44999998888',
            birthDate: '1990-05-20',
          ),
        );
      });

      test('deve entrar sozinho com o e-mail e a senha digitados (RM12)', () async {
        final outcome = await submit();

        expect(outcome, RegistrationOutcome.signedIn);
        expect(fakes.auth.signInCalls.single, (email: _email, password: _password));
        expect(container.read(authControllerProvider), AuthAuthenticated(clientProfile));
      });

      test('deve esperar 1 minuto para o reenvio do e-mail de confirmação (RM14)', () async {
        await submit(email: ' Maria.Silva@Exemplo.com ');

        expect(
          container.read(emailVerificationControllerProvider),
          const EmailVerificationState(email: _email, cooldownSeconds: 60),
        );
      });

      test('deve continuar no carregando até o fim do login automático', () async {
        final pending = fakes.auth.signInPending = Completer<SignInResult>();

        final outcome = submit();
        await pumpEventQueue();

        expect(state(), const RegistrationState(isSubmitting: true));

        pending.complete(const SignInSuccess());
        expect(await outcome, RegistrationOutcome.signedIn);
      });

      for (final (description, configure) in [
        (
          'com a senha recusada no login',
          (AuthFakes fakes) => fakes.auth.signInResult = const SignInWrongCredentials(),
        ),
        (
          'sem conexão no login',
          (AuthFakes fakes) => fakes.auth.signInError = const NetworkException(),
        ),
      ]) {
        test(
          'deve levar ao login quando o login automático não entra, $description (RM12)',
          () async {
            configure(fakes);

            final outcome = await submit();

            expect(outcome, RegistrationOutcome.signInFailed);
            expect(state(), const RegistrationState());
            expect(container.read(authControllerProvider), const AuthUnauthenticated());
          },
        );
      }
    });

    group('conferência antes de enviar (RM11)', () {
      test('deve pedir cada campo vazio, sem chamar a API', () async {
        final outcome = await submit(
          name: '',
          email: '',
          password: '',
          cpf: '',
          phone: '',
          birthDate: '',
        );

        expect(outcome, isNull);
        expect(fakes.registration.calls, isEmpty);
        expect(state().fieldErrors.keys, RegistrationField.values);
      });

      test('deve recusar a data incompleta pelo formato', () async {
        await submit(birthDate: '20/05/19');

        expect(
          state().errorFor(RegistrationField.birthDate),
          'Data de nascimento inválida. Use o formato DD/MM/AAAA.',
        );
        expect(fakes.registration.calls, isEmpty);
      });

      test('deve recusar o CPF com os dígitos verificadores errados', () async {
        await submit(cpf: '529.982.247-35');

        expect(state().fieldErrors, {RegistrationField.cpf: 'CPF inválido.'});
      });
    });

    group('respostas da API', () {
      test('deve mostrar a mensagem de cada campo do 400 (RM11)', () async {
        const errors = {RegistrationField.phone: 'Telefone inválido. Informe o DDD e o número.'};
        fakes.registration.result = const RegistrationFieldErrors(errors);

        final outcome = await submit();

        expect(outcome, isNull);
        expect(state(), const RegistrationState(fieldErrors: errors));
        expect(state().isEmailInUse, isFalse);
        expect(fakes.auth.signInCalls, isEmpty);
      });

      test('deve marcar o e-mail que já tem conta no 409', () async {
        fakes.registration.result = const RegistrationFieldErrors({
          RegistrationField.email: 'E-mail já cadastrado.',
        }, alreadyInUse: RegistrationField.email);

        await submit();

        expect(state().errorFor(RegistrationField.email), 'E-mail já cadastrado.');
        expect(state().isEmailInUse, isTrue);
      });

      test('não deve oferecer os atalhos do e-mail no 409 do CPF', () async {
        fakes.registration.result = const RegistrationFieldErrors({
          RegistrationField.cpf: 'CPF já cadastrado.',
        }, alreadyInUse: RegistrationField.cpf);

        await submit();

        expect(state().errorFor(RegistrationField.cpf), 'CPF já cadastrado.');
        expect(state().isEmailInUse, isFalse);
      });

      for (final (description, error) in [
        ('sem conexão', const NetworkException()),
        ('com a API fora do ar', const ServerException(statusCode: 500)),
        ('no 400 sem campo', const ValidationException(message: 'Dados inválidos.')),
      ]) {
        test('deve mostrar a mensagem $description', () async {
          fakes.registration.error = error;

          final outcome = await submit();

          expect(outcome, isNull);
          expect(state(), RegistrationState(message: error.message));
        });
      }

      test('deve ignorar um segundo envio no meio do primeiro', () async {
        final pending = fakes.registration.pending = Completer<RegistrationResult>();

        final first = submit();
        final second = await submit();

        expect(second, isNull);
        expect(fakes.registration.calls, hasLength(1));

        pending.complete(const RegistrationSuccess());
        await first;
      });

      test('não deve entrar quando a tela fecha durante o cadastro', () async {
        final pending = fakes.registration.pending = Completer<RegistrationResult>();
        final outcome = submit();

        screen.close();
        await pumpEventQueue();
        pending.complete(const RegistrationSuccess());

        expect(await outcome, isNull);
        expect(fakes.auth.signInCalls, isEmpty);
      });
    });

    group('fieldChanged', () {
      test('deve tirar só o erro do campo editado', () async {
        await submit(cpf: '', phone: '');

        sut().fieldChanged(RegistrationField.cpf);

        expect(state().fieldErrors, {RegistrationField.phone: 'Informe o telefone.'});
      });

      test('deve tirar os atalhos do e-mail que já tem conta quando o e-mail muda', () async {
        fakes.registration.result = const RegistrationFieldErrors({
          RegistrationField.email: 'E-mail já cadastrado.',
        }, alreadyInUse: RegistrationField.email);
        await submit();

        sut().fieldChanged(RegistrationField.email);

        expect(state(), const RegistrationState());
      });

      test('não deve mudar o estado quando o campo não tem erro', () async {
        await submit(cpf: '');
        final before = state();

        sut().fieldChanged(RegistrationField.name);

        expect(state(), same(before));
      });
    });

    group('contagem do limite por IP', () {
      test('deve desativar o "Criar conta" com a contagem e voltar sozinho no fim dela', () {
        fakes.registration.result = const RegistrationRateLimited(retryAfter: Duration(seconds: 2));

        fakeAsync((async) {
          unawaited(submit());
          async.flushMicrotasks();

          expect(
            state(),
            const RegistrationState(
              message: 'Muitas tentativas. Tente de novo em 2 s.',
              retrySeconds: 2,
            ),
          );
          expect(state().canSubmit, isFalse);

          RegistrationOutcome? ignored = RegistrationOutcome.signedIn;
          unawaited(submit().then((value) => ignored = value));
          async.flushMicrotasks();
          expect(ignored, isNull);
          expect(fakes.registration.calls, hasLength(1));

          async.elapse(const Duration(seconds: 1));

          expect(
            state(),
            const RegistrationState(
              message: 'Muitas tentativas. Tente de novo em 1 s.',
              retrySeconds: 1,
              announceMessage: false,
            ),
          );

          async.elapse(const Duration(seconds: 1));

          expect(state(), const RegistrationState());
          expect(async.periodicTimerCount, 0);
        });
      });

      test('deve parar a contagem quando a tela fecha', () {
        fakes.registration.result = const RegistrationRateLimited(retryAfter: Duration(seconds: 5));

        fakeAsync((async) {
          unawaited(submit());
          async.flushMicrotasks();

          screen.close();
          // O Riverpod descarta o provider sem ouvintes num Future, depois das microtasks.
          async.elapse(Duration.zero);

          expect(async.periodicTimerCount, 0);
        });
      });
    });

    test('deve comparar o estado pelo valor e descrevê-lo sem a senha', () {
      const state = RegistrationState(
        fieldErrors: {RegistrationField.cpf: 'CPF inválido.'},
        alreadyInUse: RegistrationField.cpf,
      );

      expect(
        state,
        const RegistrationState(
          fieldErrors: {RegistrationField.cpf: 'CPF inválido.'},
          alreadyInUse: RegistrationField.cpf,
        ),
      );
      expect(
        state.hashCode,
        const RegistrationState(
          fieldErrors: {RegistrationField.cpf: 'CPF inválido.'},
          alreadyInUse: RegistrationField.cpf,
        ).hashCode,
      );
      expect(state.toString(), contains('alreadyInUse: cpf'));
    });
  });
}
