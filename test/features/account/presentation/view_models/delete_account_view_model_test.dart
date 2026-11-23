import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/confirmation_password.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/delete_account_view_model.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';

const _password = 'senha-forte-1';

void main() {
  group('DeleteAccountViewModel', () {
    late AuthFakes fakes;
    late ProviderContainer container;

    setUp(() async {
      fakes = AuthFakes(signedIn: true);
      container = ProviderContainer.test(overrides: fakes.overrides, retry: noAutomaticRetry)
        ..listen(authControllerProvider, (_, _) {})
        ..listen(deleteAccountViewModelProvider, (_, _) {});
      await pumpEventQueue();
    });

    DeleteAccountViewModel sut() => container.read(deleteAccountViewModelProvider.notifier);
    DeleteAccountState state() => container.read(deleteAccountViewModelProvider);
    AuthState auth() => container.read(authControllerProvider);

    test('deve excluir a conta e voltar ao login com o aviso (RM17)', () async {
      final isPasswordCorrect = await sut().submit(_password);
      await pumpEventQueue();

      expect(isPasswordCorrect, isTrue);
      expect(fakes.profile.deleteAccountCalls, [_password]);
      expect(auth(), const AuthUnauthenticated(reason: UnauthenticatedReason.accountDeleted));
    });

    test('deve mostrar a senha incorreta no campo e continuar logado (RM15)', () async {
      fakes.profile.deleteAccountError = const BusinessRuleException(
        message: 'Senha incorreta.',
        field: 'password',
      );

      final isPasswordCorrect = await sut().submit('errada-1');

      expect(isPasswordCorrect, isFalse);
      expect(
        state(),
        const DeleteAccountState(passwordError: ConfirmationPasswordMessages.incorrect),
      );
      expect(auth(), AuthAuthenticated(clientProfile));
    });

    test('deve mostrar o erro sem conexão e manter a conta', () async {
      fakes.profile.deleteAccountError = const NetworkException();

      await sut().submit(_password);

      expect(state().message, NetworkException.defaultMessage);
      expect(auth(), AuthAuthenticated(clientProfile));
    });

    test('deve ignorar a senha vazia e o envio durante outro', () async {
      await sut().submit('');
      expect(fakes.profile.deleteAccountCalls, isEmpty);

      final pending = fakes.profile.deleteAccountPending = Completer<void>();
      final first = sut().submit(_password);
      await pumpEventQueue();
      expect(state().isSubmitting, isTrue);
      await sut().submit(_password);
      pending.complete();
      await first;

      expect(fakes.profile.deleteAccountCalls, hasLength(1));
    });

    test('deve tirar o erro da senha quando ela muda', () async {
      fakes.profile.deleteAccountError = const BusinessRuleException(field: 'password');
      await sut().submit('errada-1');

      sut().passwordChanged();

      expect(state(), const DeleteAccountState());
      final before = state();
      sut().passwordChanged();
      expect(state(), same(before));
    });

    test('deve comparar o estado pelo valor', () {
      const a = DeleteAccountState(passwordError: 'erro');

      expect(a, const DeleteAccountState(passwordError: 'erro'));
      expect(a.hashCode, const DeleteAccountState(passwordError: 'erro').hashCode);
      expect(a.toString(), contains('passwordError: erro'));
    });
  });
}
