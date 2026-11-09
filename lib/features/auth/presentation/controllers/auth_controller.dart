import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/core/auth/session_manager.dart';
import 'package:reportaai_cm/core/auth/session_manager_provider.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/auth_providers.dart';
import 'package:reportaai_cm/features/auth/domain/models/sign_in_result.dart';
import 'package:reportaai_cm/features/auth/domain/repositories/auth_repository.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/profile/domain/models/role.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_profile.dart';
import 'package:reportaai_cm/features/profile/domain/repositories/profile_repository.dart';
import 'package:reportaai_cm/features/profile/profile_providers.dart';

/// O estado de login do app inteiro. Não é `autoDispose`: o `routerProvider` o ouve enquanto o
/// app estiver aberto.
final NotifierProvider<AuthController, AuthState> authControllerProvider = NotifierProvider(
  AuthController.new,
);

/// A fonte da verdade do login: confere a sessão na abertura, entra, sai e acompanha o fim da
/// sessão. As telas chamam as ações e ouvem o [AuthState], e o redirect das rotas leva à tela
/// certa.
///
/// Depois que existe uma sessão, na abertura ou no login, os passos são sempre os mesmos: a
/// segunda etapa pendente (RM08), o `GET /api/users/me` e o papel CLIENT (RM01).
final class AuthController extends Notifier<AuthState> {
  late AuthRepository _auth;
  late ProfileRepository _profile;

  /// Conta as operações (abertura, login e saída) e os eventos da sessão. Uma operação só guarda
  /// o resultado se nada mudou o estado enquanto ela esperava a API.
  int _operation = 0;

  /// Começa conferindo a sessão guardada: o app abre na tela de abertura.
  @override
  AuthState build() {
    _auth = ref.watch(authRepositoryProvider);
    _profile = ref.watch(profileRepositoryProvider);

    final subscription = ref.watch(sessionManagerProvider).events.listen(_onSessionEvent);
    ref.onDispose(subscription.cancel);

    unawaited(_settle(_restoreSession));
    return const AuthChecking();
  }

  /// "Tentar de novo" da tela de abertura, quando o perfil não carregou (RM06).
  Future<void> retry() {
    _setState(const AuthChecking());
    return _settle(_restoreSession);
  }

  /// Entra com o [email] e a [password]. O estado continua `AuthUnauthenticated` até o fim dos
  /// passos depois do login, e a tela de login mostra o carregando enquanto espera.
  ///
  /// Devolve o [SignInResult], para a tela de login mostrar a mensagem de cada caso. Sem conexão
  /// ou num erro da API, lança a `ApiException`, e o usuário continua no login.
  Future<SignInResult> signIn({required String email, required String password}) async {
    // O motivo de ter voltado ao login sai da tela assim que o usuário tenta de novo.
    _setState(const AuthUnauthenticated());

    final result = await _auth.signIn(email: email, password: password);
    if (result is SignInSuccess) await _settle(_enter);

    return result;
  }

  /// "Sair": encerra a sessão na API e volta ao login, sem aviso. Sem conexão, lança a
  /// `NetworkException`, e o usuário continua logado (RM10).
  Future<void> signOut() async {
    await _auth.signOut();

    _setState(const AuthUnauthenticated());
  }

  /// O que mudou na sessão sem o app pedir. Um evento que não muda o estado atual é ignorado: o
  /// mesmo evento pode chegar mais de uma vez, e o `expired` também chega numa chamada sem
  /// sessão.
  void _onSessionEvent(SessionEvent event) {
    final next = switch ((event, state)) {
      (_, AuthUnauthenticated()) => null,
      // A sessão que existia acabou, inclusive na abertura (ex.: o refresh token venceu com o app
      // fechado). A operação em andamento é descartada (RM07).
      (SessionEvent.expired, _) => const AuthUnauthenticated(
        reason: UnauthenticatedReason.sessionExpired,
      ),
      // Na abertura, quem saiu foi a própria operação (RM01 e RM08), e ela guarda o motivo.
      (SessionEvent.signedOut, AuthChecking()) => null,
      (SessionEvent.signedOut, _) => const AuthUnauthenticated(),
    };

    if (next != null) _setState(next);
  }

  /// Na abertura e no "Tentar de novo": sem sessão guardada, vai para o login sem aviso.
  Future<AuthState> _restoreSession() async {
    if (!await _auth.hasSession()) return const AuthUnauthenticated();

    return await _enter();
  }

  /// Os passos depois que existe uma sessão: segunda etapa, perfil e papel.
  Future<AuthState> _enter() async {
    if (await _auth.isSecondFactorPending()) {
      return await _leave(UnauthenticatedReason.secondFactorPending);
    }

    final UserProfile profile;
    try {
      profile = await _profile.getMe();
    } on SecondFactorPendingException {
      // A claim mudou entre a conferência e a chamada (ex.: a verificação foi ativada no meio).
      return await _leave(UnauthenticatedReason.secondFactorPending);
    }

    if (profile.role != Role.client) return await _leave(UnauthenticatedReason.roleNotAllowed);

    return AuthAuthenticated(profile);
  }

  /// Encerra a sessão que não pode entrar no app e volta ao login com o [reason].
  Future<AuthState> _leave(UnauthenticatedReason reason) async {
    try {
      await _auth.signOut();
    } on ApiException {
      // Sem resposta da API, os tokens continuam no aparelho, mas o app não entra: a próxima
      // abertura confere a sessão de novo.
    }

    return AuthUnauthenticated(reason: reason);
  }

  /// Roda os [steps] de uma operação e guarda o estado a que eles chegam. Se outra operação ou
  /// um evento da sessão mudou o estado no meio, o resultado é descartado.
  Future<void> _settle(Future<AuthState> Function() steps) async {
    final operation = ++_operation;

    AuthState next;
    try {
      next = await steps();
    } on UnauthorizedException {
      // A API recusou a sessão e o SDK a apagou (RM07).
      next = const AuthUnauthenticated(reason: UnauthenticatedReason.sessionExpired);
    } on Object catch (error) {
      // Sem rede ou com a API fora do ar: a sessão continua guardada, para tentar de novo (RM06).
      next = AuthLoadFailed(error);
    }

    if (operation == _operation) _setState(next);
  }

  /// Muda o estado e descarta a operação em andamento.
  void _setState(AuthState next) {
    _operation++;
    // O provider pode ter sido descartado enquanto a operação esperava a API.
    if (ref.mounted) state = next;
  }
}
