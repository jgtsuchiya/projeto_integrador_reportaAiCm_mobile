import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/change_password_view_model.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/confirmation_password.dart';
import 'package:reportaai_cm/features/auth/domain/models/password.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';

const _current = 'senha-forte-1';
const _new = 'senha-nova-2';

void main() {
  group('ChangePasswordViewModel', () {
    late AuthFakes fakes;
    late ProviderContainer container;

    setUp(() async {
      fakes = AuthFakes(signedIn: true);
      container = ProviderContainer.test(overrides: fakes.overrides, retry: noAutomaticRetry)
        ..listen(authControllerProvider, (_, _) {})
        ..listen(changePasswordViewModelProvider, (_, _) {});
      await pumpEventQueue();
    });

    ChangePasswordViewModel sut() => container.read(changePasswordViewModelProvider.notifier);
    ChangePasswordState state() => container.read(changePasswordViewModelProvider);

    Future<ChangePasswordOutcome?> submit({
      String currentPassword = _current,
      String newPassword = _new,
      String? confirmation,
    }) => sut().submit(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmation: confirmation ?? newPassword,
    );

    test('deve trocar a senha e continuar logado (RM16)', () async {
      final outcome = await submit();

      expect(outcome, ChangePasswordOutcome.changed);
      expect(fakes.profile.changePasswordCalls, [(currentPassword: _current, newPassword: _new)]);
      expect(container.read(authControllerProvider), AuthAuthenticated(clientProfile));
      expect(state(), const ChangePasswordState());
    });

    test('deve mostrar a senha atual incorreta no campo, sem levar ao login (RM15)', () async {
      fakes.profile.changePasswordError = const BusinessRuleException(
        message: 'Senha incorreta.',
        field: 'currentPassword',
      );

      final outcome = await submit();

      expect(outcome, ChangePasswordOutcome.incorrectPassword);
      expect(state().fieldErrors, {
        ChangePasswordField.currentPassword: ConfirmationPasswordMessages.incorrect,
      });
      expect(container.read(authControllerProvider), AuthAuthenticated(clientProfile));
    });

    for (final (description, currentPassword, newPassword, confirmation, errors) in [
      (
        'os campos vazios',
        '',
        '',
        '',
        {
          ChangePasswordField.currentPassword: ConfirmationPasswordMessages.missing,
          ChangePasswordField.newPassword: ChangePasswordViewModel.newPasswordMissingMessage,
          ChangePasswordField.confirmation: ChangePasswordViewModel.confirmationMissingMessage,
        },
      ),
      (
        'a senha nova fora da política (RN08)',
        _current,
        'curta1',
        'curta1',
        {ChangePasswordField.newPassword: PasswordMessages.length},
      ),
      (
        'a confirmação diferente',
        _current,
        _new,
        'senha-nova-3',
        {ChangePasswordField.confirmation: ChangePasswordViewModel.confirmationMismatchMessage},
      ),
    ]) {
      test('deve recusar $description sem chamar a API', () async {
        final outcome = await submit(
          currentPassword: currentPassword,
          newPassword: newPassword,
          confirmation: confirmation,
        );

        expect(outcome, isNull);
        expect(state().fieldErrors, errors);
        expect(fakes.profile.changePasswordCalls, isEmpty);
      });
    }

    test('deve mostrar o 400 da senha nova embaixo dela', () async {
      fakes.profile.changePasswordError = const ValidationException(
        fieldErrors: [FieldError(field: 'newPassword', message: 'A senha é fraca.')],
      );

      final outcome = await submit();

      expect(outcome, isNull);
      expect(state().fieldErrors, {ChangePasswordField.newPassword: 'A senha é fraca.'});
    });

    test('deve mostrar a mensagem geral do 400 sem um campo conhecido', () async {
      fakes.profile.changePasswordError = const ValidationException(message: 'Dados inválidos.');

      await submit();

      expect(state(), const ChangePasswordState(message: 'Dados inválidos.'));
    });

    test('deve mostrar o erro sem conexão', () async {
      fakes.profile.changePasswordError = const NetworkException();

      final outcome = await submit();

      expect(outcome, isNull);
      expect(state().message, NetworkException.defaultMessage);
    });

    test('deve ignorar o envio durante outro', () async {
      final pending = fakes.profile.changePasswordPending = Completer<void>();

      final first = submit();
      await pumpEventQueue();
      expect(state().isSubmitting, isTrue);
      expect(await submit(), isNull);
      pending.complete();
      await first;

      expect(fakes.profile.changePasswordCalls, hasLength(1));
    });

    test('deve tirar o erro do campo editado e manter o dos outros', () async {
      await submit(currentPassword: '', newPassword: '', confirmation: '');

      sut().fieldChanged(ChangePasswordField.currentPassword);

      expect(state().errorFor(ChangePasswordField.currentPassword), isNull);
      expect(state().errorFor(ChangePasswordField.newPassword), isNotNull);
      final before = state();
      sut().fieldChanged(ChangePasswordField.currentPassword);
      expect(state(), same(before));
    });

    test('deve comparar o estado pelo valor', () {
      const a = ChangePasswordState(fieldErrors: {ChangePasswordField.newPassword: 'erro'});
      const b = ChangePasswordState(fieldErrors: {ChangePasswordField.newPassword: 'erro'});

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('erro'));
    });
  });

  group('isIncorrectPassword', () {
    test('deve reconhecer só o 422 com o campo da senha', () {
      expect(isIncorrectPassword(const BusinessRuleException(field: 'currentPassword')), isTrue);
      expect(isIncorrectPassword(const BusinessRuleException(field: 'password')), isTrue);
      expect(isIncorrectPassword(const BusinessRuleException(field: 'code')), isFalse);
      expect(isIncorrectPassword(const BusinessRuleException()), isFalse);
      expect(isIncorrectPassword(const UnauthorizedException()), isFalse);
    });
  });
}
