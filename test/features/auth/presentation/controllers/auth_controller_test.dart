import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/app.dart';
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
const _secondFactorPending = AuthUnauthenticated(reason: UnauthenticatedReason.secondFactorPending);

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

      test('deve sair e avisar com a sessão pendente da segunda etapa (RM08)', () async {
        fakes.session
          ..hasStoredSession = true
          ..secondFactorPending = true;

        await open();

        expect(state(), _secondFactorPending);
        expect(fakes.session.signOutCalls, 1);
        expect(fakes.profile.calls, 0, reason: 'A sessão pendente não chama o /users/me.');
      });

      test('deve sair e avisar quando o perfil responde que falta a segunda etapa', () async {
        fakes.session.hasStoredSession = true;
        fakes.profile.error = const SecondFactorPendingException();

        await open();

        expect(state(), _secondFactorPending);
        expect(fakes.session.signOutCalls, 1);
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

      test('deve sair e avisar no login com a segunda etapa pendente (RM08)', () async {
        await open();
        fakes.session.secondFactorPending = true;

        await signIn();

        expect(state(), _secondFactorPending);
        expect(fakes.session.signOutCalls, 1);
      });

      test('deve ir para a abertura com o erro quando o perfil não carrega no login', () async {
        await open();
        fakes.profile.error = const NetworkException();

        await signIn();

        expect(state(), _loadFailedWith<NetworkException>());
        expect(fakes.session.hasStoredSession, isTrue);
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
