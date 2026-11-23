import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/core/auth/session_manager.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/domain/models/sign_in_result.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/profile/domain/models/role.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_profile.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';

const _email = 'maria.silva@exemplo.com';
const _password = 'SenhaSecreta123';

const _signedOut = AuthUnauthenticated();
const _sessionExpired = AuthUnauthenticated(reason: UnauthenticatedReason.sessionExpired);
const _roleNotAllowed = AuthUnauthenticated(reason: UnauthenticatedReason.roleNotAllowed);
const _accountDeleted = AuthUnauthenticated(reason: UnauthenticatedReason.accountDeleted);

/// O Client do exemplo com outro papel.
UserProfile _profileWith(Role role) => UserProfile(
  id: clientProfile.id,
  role: role,
  name: clientProfile.name,
  email: clientProfile.email,
  status: clientProfile.status,
  mfaEnabled: clientProfile.mfaEnabled,
  createdAt: clientProfile.createdAt,
  updatedAt: clientProfile.updatedAt,
);

Matcher _loadFailedWith<T>() =>
    isA<AuthLoadFailed>().having((state) => state.error, 'error', isA<T>());

void main() {
  group('AuthController', () {
    late AuthFakes fakes;
    late ProviderContainer container;

    setUp(() {
      fakes = AuthFakes();
      container = ProviderContainer.test(overrides: fakes.overrides, retry: noAutomaticRetry);
    });

    AuthController sut() => container.read(authControllerProvider.notifier);
    AuthState state() => container.read(authControllerProvider);

    /// Abre o app: o AuthController confere a sessão guardada, e o teste espera a conferência
    /// terminar. Devolve os estados por que ele passou, na ordem, como o router os vê.
    Future<List<AuthState>> open() async {
      final states = <AuthState>[];
      container.listen(
        authControllerProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      await pumpEventQueue();
      return states;
    }

    group('na abertura', () {
      test('deve ir para o login, sem aviso, sem a sessão guardada', () async {
        final states = await open();

        expect(states, [const AuthChecking(), _signedOut]);
        expect(fakes.profile.calls, 0);
      });

      test('deve entrar direto com a sessão guardada de um Client (RM06)', () async {
        fakes.session.hasStoredSession = true;

        final states = await open();

        expect(states, [const AuthChecking(), AuthAuthenticated(clientProfile)]);
        expect(fakes.profile.calls, 1);
      });

      test('deve ir para a tela do código com a sessão pendente da segunda etapa (RM18)', () async {
        fakes.session
          ..hasStoredSession = true
          ..secondFactorPending = true;

        final states = await open();

        expect(states, [const AuthChecking(), const AuthSecondFactorPending()]);
        expect(fakes.session.signOutCalls, 0, reason: 'A sessão pendente continua (fim da RM08).');
        expect(fakes.profile.calls, 0, reason: 'A sessão pendente não chama o /users/me.');
      });

      test('deve ir para a tela do código quando o perfil responde que falta a etapa', () async {
        fakes.session.hasStoredSession = true;
        fakes.profile.error = const SecondFactorPendingException();

        await open();

        expect(state(), const AuthSecondFactorPending());
        expect(fakes.session.signOutCalls, 0);
      });

      for (final role in [Role.admin, Role.superAdmin, Role.unknown]) {
        test('deve sair e avisar com o papel ${role.name}, que não é o CLIENT (RM01)', () async {
          fakes.session.hasStoredSession = true;
          fakes.profile.result = _profileWith(role);

          await open();

          expect(state(), _roleNotAllowed);
          expect(fakes.session.signOutCalls, 1);
          expect(fakes.session.hasStoredSession, isFalse);
        });
      }

      test('deve voltar ao login com o aviso mesmo sem conseguir encerrar a sessão', () async {
        fakes.session
          ..hasStoredSession = true
          ..signOutError = const NetworkException();
        fakes.profile.result = adminProfile;

        await open();

        expect(state(), _roleNotAllowed);
      });

      test('deve mostrar o erro sem rede, sem apagar a sessão (RM06)', () async {
        fakes.session.hasStoredSession = true;
        fakes.profile.error = const NetworkException();

        final states = await open();

        expect(states, [const AuthChecking(), _loadFailedWith<NetworkException>()]);
        expect(fakes.session.signOutCalls, 0);
        expect(fakes.session.hasStoredSession, isTrue);
      });

      test('deve mostrar o erro sem rede para conferir a segunda etapa', () async {
        fakes.session
          ..hasStoredSession = true
          ..secondFactorError = const NetworkException();

        await open();

        expect(state(), _loadFailedWith<NetworkException>());
      });

      test('deve mostrar o erro com a API fora do ar', () async {
        fakes.session.hasStoredSession = true;
        fakes.profile.error = const ServerException(statusCode: 500);

        await open();

        expect(state(), _loadFailedWith<ServerException>());
      });

      test('deve voltar ao login com o aviso quando a API recusa a sessão (RM07)', () async {
        fakes.session.hasStoredSession = true;
        fakes.profile.error = const UnauthorizedException();

        await open();

        expect(state(), _sessionExpired);
      });

      test('deve voltar ao login com o aviso quando a renovação da sessão é recusada', () async {
        fakes.session
          ..hasStoredSession = true
          ..secondFactorError = const UnauthorizedException();

        await open();

        expect(state(), _sessionExpired);
      });
    });

    group('retry', () {
      test('deve conferir de novo, passando pela abertura, e entrar com a rede de volta', () async {
        fakes.session.hasStoredSession = true;
        fakes.profile.error = const NetworkException();
        await open();
        fakes.profile.error = null;

        final retry = sut().retry();

        expect(state(), const AuthChecking());

        await retry;

        expect(state(), AuthAuthenticated(clientProfile));
        expect(fakes.profile.calls, 2);
      });

      test('deve mostrar o erro de novo se a rede continua fora', () async {
        fakes.session.hasStoredSession = true;
        fakes.profile.error = const NetworkException();
        await open();

        await sut().retry();

        expect(state(), _loadFailedWith<NetworkException>());
      });
    });

    group('signIn', () {
      Future<SignInResult> signIn() => sut().signIn(email: _email, password: _password);

      test('deve entrar com um Client e guardar o perfil', () async {
        await open();

        final result = await signIn();

        expect(result, const SignInSuccess());
        expect(state(), AuthAuthenticated(clientProfile));
        expect(fakes.auth.signInCalls.single, (email: _email, password: _password));
      });

      test('deve devolver o resultado e continuar no login quando não entra', () async {
        await open();
        fakes.auth.signInResult = const SignInWrongCredentials();

        final result = await signIn();

        expect(result, const SignInWrongCredentials());
        expect(state(), _signedOut);
        expect(fakes.profile.calls, 0);
      });

      test('deve tirar o aviso anterior assim que o usuário tenta de novo', () async {
        fakes.session.hasStoredSession = true;
        fakes.profile.error = const UnauthorizedException();
        await open();
        expect(state(), _sessionExpired);
        fakes.auth.signInResult = const SignInWrongCredentials();

        await signIn();

        expect(state(), _signedOut);
      });

      test('deve lançar o erro sem conexão e continuar no login', () async {
        await open();
        fakes.auth.signInError = const NetworkException();

        await expectLater(signIn(), throwsA(isA<NetworkException>()));

        expect(state(), _signedOut);
      });

      test('deve sair e avisar no login de um ADMIN (RM01)', () async {
        await open();
        fakes.profile.result = adminProfile;

        final result = await signIn();

        expect(result, const SignInSuccess());
        expect(state(), _roleNotAllowed);
        expect(fakes.session.signOutCalls, 1);
        expect(fakes.session.hasStoredSession, isFalse);
      });

      test('deve ir para a tela do código no login com a segunda etapa pendente (RM18)', () async {
        await open();
        fakes.session.secondFactorPending = true;

        final result = await signIn();

        expect(result, const SignInSuccess());
        expect(state(), const AuthSecondFactorPending());
        expect(fakes.session.signOutCalls, 0);
        expect(fakes.profile.calls, 0);
      });

      test('deve ir para a abertura com o erro quando o perfil não carrega no login', () async {
        await open();
        fakes.profile.error = const NetworkException();

        await signIn();

        expect(state(), _loadFailedWith<NetworkException>());
        expect(fakes.session.hasStoredSession, isTrue);
      });
    });

    group('refreshProfile', () {
      final verifiedProfile = clientProfileWith(emailVerifiedAt: DateTime.utc(2026, 10, 5, 12));

      setUp(() => fakes.session.hasStoredSession = true);

      test('deve guardar o perfil novo, como o e-mail confirmado no navegador', () async {
        await open();
        fakes.profile.result = verifiedProfile;

        await sut().refreshProfile();

        expect(state(), AuthAuthenticated(verifiedProfile));
        expect(fakes.profile.calls, 2);
        expect(fakes.session.signOutCalls, 0);
      });

      for (final error in [const NetworkException(), const ServerException(statusCode: 500)]) {
        test('deve lançar a ${error.runtimeType} e continuar com o perfil que já tinha', () async {
          await open();
          fakes.profile.error = error;

          await expectLater(sut().refreshProfile(), throwsA(error));

          expect(state(), AuthAuthenticated(clientProfile));
          expect(fakes.session.hasStoredSession, isTrue);
        });
      }

      test('deve voltar ao login com o aviso quando a API recusa a sessão (RM07)', () async {
        await open();
        fakes.profile.error = const UnauthorizedException();

        await sut().refreshProfile();

        expect(state(), _sessionExpired);
      });

      test('deve sair e avisar quando o papel não é mais o CLIENT (RM01)', () async {
        await open();
        fakes.profile.result = adminProfile;

        await sut().refreshProfile();
        await pumpEventQueue();

        // O evento da saída chega com a tela inicial aberta e não apaga o motivo.
        expect(state(), _roleNotAllowed);
        expect(fakes.session.signOutCalls, 1);
      });

      test('deve ir para a tela do código quando o perfil responde que falta a etapa', () async {
        await open();
        fakes.profile.error = const SecondFactorPendingException();

        await sut().refreshProfile();
        await pumpEventQueue();

        expect(state(), const AuthSecondFactorPending());
        expect(fakes.session.signOutCalls, 0);
      });

      test('não deve buscar o perfil sem o Client dentro', () async {
        fakes.session.hasStoredSession = false;
        await open();

        await sut().refreshProfile();

        expect(state(), _signedOut);
        expect(fakes.profile.calls, 0);
      });

      test('deve descartar o perfil quando a sessão acaba no meio da atualização', () async {
        await open();
        final profile = fakes.profile.pending = Completer<UserProfile>();

        final refresh = sut().refreshProfile();
        fakes.session.expire();
        await pumpEventQueue();
        profile.complete(verifiedProfile);
        await refresh;

        expect(state(), _sessionExpired);
      });

      test('deve descartar o perfil quando o usuário sai no meio da atualização', () async {
        await open();
        final profile = fakes.profile.pending = Completer<UserProfile>();

        final refresh = sut().refreshProfile();
        await sut().signOut();
        profile.complete(verifiedProfile);
        await refresh;

        expect(state(), _signedOut);
      });
    });

    group('verifySecondFactor', () {
      setUp(() {
        fakes.session
          ..hasStoredSession = true
          ..secondFactorPending = true;
      });

      test('deve concluir o login com o código certo e guardar o perfil (RM18)', () async {
        await open();

        await sut().verifySecondFactor('042137');

        expect(state(), AuthAuthenticated(clientProfile));
        expect(fakes.auth.verifyLoginCodeCalls, ['042137']);
        expect(fakes.profile.calls, 1);
      });

      test('deve lançar o erro do código errado e continuar na tela do código', () async {
        await open();
        fakes.auth.verifyLoginCodeError = const BusinessRuleException(
          message: 'Código inválido ou expirado.',
          field: 'code',
        );

        await expectLater(
          sut().verifySecondFactor('000000'),
          throwsA(isA<BusinessRuleException>()),
        );

        expect(state(), const AuthSecondFactorPending());
        expect(fakes.profile.calls, 0);
      });

      test('deve lançar o erro sem conexão e continuar na tela do código', () async {
        await open();
        fakes.auth.verifyLoginCodeError = const NetworkException();

        await expectLater(sut().verifySecondFactor('042137'), throwsA(isA<NetworkException>()));

        expect(state(), const AuthSecondFactorPending());
      });

      test('deve sair e avisar quando o papel não é o CLIENT, depois do código (RM01)', () async {
        fakes.profile.result = adminProfile;
        await open();

        await sut().verifySecondFactor('042137');

        expect(state(), _roleNotAllowed);
        expect(fakes.session.signOutCalls, 1);
      });

      test('não deve conferir o código sem a sessão pendente', () async {
        fakes.session.secondFactorPending = false;
        await open();

        await sut().verifySecondFactor('042137');

        expect(fakes.auth.verifyLoginCodeCalls, isEmpty);
        expect(state(), AuthAuthenticated(clientProfile));
      });

      test('deve voltar ao login, sem aviso, com o "Sair" da tela do código', () async {
        await open();

        await sut().signOut();
        await pumpEventQueue();

        expect(state(), _signedOut);
        expect(fakes.session.hasStoredSession, isFalse);
      });

      test('deve voltar ao login com o aviso quando a sessão pendente acaba (RM07)', () async {
        await open();

        fakes.session.expire();
        await pumpEventQueue();

        expect(state(), _sessionExpired);
      });
    });

    group('replaceProfile', () {
      test('deve trocar o perfil do Client dentro, sem buscar de novo', () async {
        fakes.session.hasStoredSession = true;
        await open();
        final updated = clientProfileWith(name: 'Maria Souza');

        sut().replaceProfile(updated);

        expect(state(), AuthAuthenticated(updated));
        expect(fakes.profile.calls, 1, reason: 'Só a busca da abertura.');
      });

      test('deve ignorar o perfil sem o Client dentro', () async {
        await open();

        sut().replaceProfile(clientProfile);

        expect(state(), _signedOut);
      });

      test('deve descartar a atualização em andamento, que traria o perfil antigo', () async {
        fakes.session.hasStoredSession = true;
        await open();
        final stale = fakes.profile.pending = Completer<UserProfile>();
        final refresh = sut().refreshProfile();
        final updated = clientProfileWith(name: 'Maria Souza');

        sut().replaceProfile(updated);
        stale.complete(clientProfile);
        await refresh;

        expect(state(), AuthAuthenticated(updated));
      });
    });

    group('deleteAccount', () {
      setUp(() => fakes.session.hasStoredSession = true);

      test('deve excluir a conta, apagar a sessão e avisar no login (RM17)', () async {
        await open();

        await sut().deleteAccount(password: _password);
        await pumpEventQueue();

        expect(state(), _accountDeleted);
        expect(fakes.profile.deleteAccountCalls, [_password]);
        expect(fakes.session.signOutCalls, 1);
        expect(fakes.session.hasStoredSession, isFalse);
      });

      test(
        'deve avisar a exclusão, e não a sessão expirada, quando o SDK avisa o fim dela',
        () async {
          // Com a conta excluída, a API recusa o signout e a renovação, e o SDK apaga os tokens
          // como se a sessão tivesse vencido.
          fakes.session.signOutEvent = SessionEvent.expired;
          await open();

          await sut().deleteAccount(password: _password);
          await pumpEventQueue();

          expect(state(), _accountDeleted);
        },
      );

      test('deve avisar a exclusão mesmo sem conseguir apagar a sessão do aparelho', () async {
        await open();
        fakes.session.signOutError = const NetworkException();

        await sut().deleteAccount(password: _password);

        expect(state(), _accountDeleted);
      });

      test('deve lançar o erro da senha incorreta e continuar logado (RM15)', () async {
        await open();
        fakes.profile.deleteAccountError = const BusinessRuleException(
          message: 'Senha incorreta.',
          field: 'password',
        );

        await expectLater(
          sut().deleteAccount(password: 'errada-1'),
          throwsA(isA<BusinessRuleException>()),
        );

        expect(state(), AuthAuthenticated(clientProfile));
        expect(fakes.session.signOutCalls, 0);
      });

      test('não deve excluir sem o Client dentro', () async {
        fakes.session.hasStoredSession = false;
        await open();

        await sut().deleteAccount(password: _password);

        expect(fakes.profile.deleteAccountCalls, isEmpty);
      });
    });

    group('signOut', () {
      test('deve encerrar a sessão e voltar ao login, sem aviso', () async {
        fakes.session.hasStoredSession = true;
        await open();

        await sut().signOut();
        await pumpEventQueue();

        expect(state(), _signedOut);
        expect(fakes.session.signOutCalls, 1);
        expect(fakes.session.hasStoredSession, isFalse);
      });

      test('deve lançar o erro sem conexão e continuar logado (RM10)', () async {
        fakes.session
          ..hasStoredSession = true
          ..signOutError = const NetworkException();
        await open();

        await expectLater(sut().signOut(), throwsA(isA<NetworkException>()));

        expect(state(), AuthAuthenticated(clientProfile));
        expect(fakes.session.hasStoredSession, isTrue);
      });

      test('deve sair da tela de erro da abertura', () async {
        fakes.session.hasStoredSession = true;
        fakes.profile.error = const NetworkException();
        await open();

        await sut().signOut();

        expect(state(), _signedOut);
      });
    });

    group('eventos da sessão', () {
      test('deve voltar ao login com o aviso quando a sessão acaba (RM07)', () async {
        fakes.session.hasStoredSession = true;
        await open();

        fakes.session.expire();
        await pumpEventQueue();

        expect(state(), _sessionExpired);
      });

      test('deve voltar ao login com o aviso quando a sessão acaba na tela de erro', () async {
        fakes.session.hasStoredSession = true;
        fakes.profile.error = const NetworkException();
        await open();

        fakes.session.expire();
        await pumpEventQueue();

        expect(state(), _sessionExpired);
      });

      test('deve ignorar o fim da sessão de quem já está no login', () async {
        await open();

        fakes.session.expire();
        await pumpEventQueue();

        expect(state(), _signedOut);
      });

      test('deve voltar ao login, sem aviso, quando a sessão é encerrada pela saída', () async {
        fakes.session.hasStoredSession = true;
        await open();

        await fakes.session.signOut();
        await pumpEventQueue();

        expect(state(), _signedOut);
      });

      test('deve descartar a abertura em andamento quando a sessão acaba no meio', () async {
        fakes.session.hasStoredSession = true;
        final profile = fakes.profile.pending = Completer<UserProfile>();
        await open();
        expect(state(), const AuthChecking());

        fakes.session.expire();
        await pumpEventQueue();
        profile.complete(clientProfile);
        await pumpEventQueue();

        expect(state(), _sessionExpired);
      });

      test('deve manter o motivo da abertura quando ela mesma encerra a sessão', () async {
        fakes.session.hasStoredSession = true;
        fakes.profile.result = adminProfile;

        final states = await open();

        // O evento de saída do signOut da RM01 chega no meio da abertura e não apaga o motivo.
        expect(states, [const AuthChecking(), _roleNotAllowed]);
      });
    });

    test('não deve mudar o estado depois de descartado', () async {
      fakes.session.hasStoredSession = true;
      final profile = fakes.profile.pending = Completer<UserProfile>();
      await open();

      container.dispose();
      profile.complete(clientProfile);
      fakes.session.expire();
      await pumpEventQueue();

      // Sem erro: o ouvinte da sessão foi cancelado, e o resultado da abertura, descartado.
    });
  });
}
