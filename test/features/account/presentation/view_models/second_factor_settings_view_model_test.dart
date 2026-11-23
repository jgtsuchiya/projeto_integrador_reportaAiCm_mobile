import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/confirmation_password.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/second_factor_settings_view_model.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';

const _password = 'senha-forte-1';

void main() {
  group('SecondFactorSettingsViewModel', () {
    late AuthFakes fakes;
    late ProviderContainer container;

    setUp(() async {
      fakes = AuthFakes(signedIn: true);
      fakes.profile.result = clientProfileWith(emailVerifiedAt: emailVerifiedAt);
      container = ProviderContainer.test(overrides: fakes.overrides, retry: noAutomaticRetry)
        ..listen(authControllerProvider, (_, _) {})
        ..listen(secondFactorSettingsViewModelProvider, (_, _) {});
      await pumpEventQueue();
    });

    SecondFactorSettingsViewModel sut() =>
        container.read(secondFactorSettingsViewModelProvider.notifier);
    SecondFactorSettingsState state() => container.read(secondFactorSettingsViewModelProvider);
    AuthState auth() => container.read(authControllerProvider);

    test('deve começar sem mudança escolhida', () {
      expect(state(), const SecondFactorSettingsState());
    });

    test('deve guardar a escolha do interruptor e tirá-la quando volta ao estado da conta', () {
      sut().select(enabled: true);
      expect(state().selected, isTrue);

      sut().select(enabled: false);
      expect(state().selected, isNull);
    });

    test('deve ativar com a senha e guardar o perfil novo no AuthController', () async {
      sut().select(enabled: true);

      final outcome = await sut().submit(_password);

      expect(outcome, SecondFactorSettingsOutcome.changed);
      expect(fakes.profile.setMfaCalls, [(enabled: true, password: _password)]);
      expect(
        auth(),
        AuthAuthenticated(clientProfileWith(emailVerifiedAt: emailVerifiedAt, mfaEnabled: true)),
      );
      expect(state(), const SecondFactorSettingsState());
    });

    test('deve desativar com a senha', () async {
      fakes.profile.result = clientProfileWith(emailVerifiedAt: emailVerifiedAt, mfaEnabled: true);
      await container.read(authControllerProvider.notifier).refreshProfile();
      sut().select(enabled: false);

      await sut().submit(_password);

      expect(fakes.profile.setMfaCalls.single.enabled, isFalse);
      expect((auth() as AuthAuthenticated).profile.mfaEnabled, isFalse);
    });

    test('deve mostrar a senha incorreta no campo, sem levar ao login (RM15)', () async {
      sut().select(enabled: true);
      fakes.profile.setMfaError = const BusinessRuleException(
        message: 'Senha incorreta.',
        field: 'password',
      );

      final outcome = await sut().submit('errada-1');

      expect(outcome, SecondFactorSettingsOutcome.incorrectPassword);
      expect(
        state(),
        const SecondFactorSettingsState(
          selected: true,
          passwordError: ConfirmationPasswordMessages.incorrect,
        ),
      );
      expect((auth() as AuthAuthenticated).profile.mfaEnabled, isFalse);
    });

    test('deve mostrar a mensagem do 422 do e-mail ainda não confirmado', () async {
      sut().select(enabled: true);
      fakes.profile.setMfaError = const BusinessRuleException(
        message: 'Verifique o seu e-mail antes de ativar a verificação em duas etapas.',
      );

      final outcome = await sut().submit(_password);

      expect(outcome, isNull);
      expect(state().message, startsWith('Verifique o seu e-mail'));
    });

    test('deve pedir a senha antes de enviar', () async {
      sut().select(enabled: true);

      final outcome = await sut().submit('');

      expect(outcome, isNull);
      expect(state().passwordError, ConfirmationPasswordMessages.missing);
      expect(fakes.profile.setMfaCalls, isEmpty);
    });

    test('não deve enviar sem mudança escolhida', () async {
      expect(await sut().submit(_password), isNull);
      expect(fakes.profile.setMfaCalls, isEmpty);
    });

    test('deve ignorar o envio e o interruptor durante outro envio', () async {
      sut().select(enabled: true);
      final pending = fakes.profile.setMfaPending = Completer<void>();

      final first = sut().submit(_password);
      await pumpEventQueue();
      sut().select(enabled: false);
      expect(state().selected, isTrue);
      expect(await sut().submit(_password), isNull);
      pending.complete();
      await first;

      expect(fakes.profile.setMfaCalls, hasLength(1));
    });

    test('deve tirar o erro da senha quando ela muda', () async {
      sut().select(enabled: true);
      await sut().submit('');

      sut().passwordChanged();

      expect(state(), const SecondFactorSettingsState(selected: true));
      final before = state();
      sut().passwordChanged();
      expect(state(), same(before));
    });

    test('deve comparar o estado pelo valor', () {
      const a = SecondFactorSettingsState(selected: true, message: 'aviso');

      expect(a, const SecondFactorSettingsState(selected: true, message: 'aviso'));
      expect(
        a.hashCode,
        const SecondFactorSettingsState(selected: true, message: 'aviso').hashCode,
      );
      expect(a.toString(), contains('selected: true'));
    });
  });
}
