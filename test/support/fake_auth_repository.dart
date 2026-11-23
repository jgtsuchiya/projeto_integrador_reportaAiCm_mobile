import 'dart:async';

import 'package:reportaai_cm/features/auth/domain/models/sign_in_result.dart';
import 'package:reportaai_cm/features/auth/domain/repositories/auth_repository.dart';

import 'fake_session_manager.dart';

/// Fake do [AuthRepository], escrito à mão como o `FakeIdentityProvider` do backend. Cada teste
/// define o resultado do próximo login e confere os logins feitos em [signInCalls].
///
/// A sessão fica no [session]: o login com sucesso a abre, e o [hasSession], o
/// [isSecondFactorPending] e o [signOut] vão para ela, como no `ApiAuthRepository`. Para o
/// teste que também ouve os eventos da sessão, passe o mesmo `FakeSessionManager` ao
/// `sessionManagerProvider`.
final class FakeAuthRepository implements AuthRepository {
  new({FakeSessionManager? session}) : session = session ?? FakeSessionManager();

  final FakeSessionManager session;

  /// Devolvido no próximo login quando não há [signInError] nem [signInPending].
  SignInResult signInResult = const SignInSuccess();

  /// Lançado no próximo login, como o repositório real lança as exceções da API.
  Exception? signInError;

  /// Enquanto não é completado, o login fica pendente: é o estado de carregando da tela.
  Completer<SignInResult>? signInPending;

  /// O e-mail e a senha de cada login, na ordem.
  final signInCalls = <({String email, String password})>[];

  /// Lançado no próximo "Esqueci minha senha", como a `RateLimitException` do 429.
  Exception? passwordResetError;

  /// Enquanto não é completado, o "Esqueci minha senha" fica pendente.
  Completer<void>? passwordResetPending;

  /// O e-mail de cada "Esqueci minha senha", na ordem, como foi digitado.
  final passwordResetCalls = <String>[];

  @override
  Future<SignInResult> signIn({required String email, required String password}) async {
    signInCalls.add((email: email, password: password));

    final pending = signInPending;
    final error = signInError;
    final SignInResult result;
    if (pending != null) {
      result = await pending.future;
    } else if (error != null) {
      throw error;
    } else {
      result = signInResult;
    }

    if (result is SignInSuccess) session.hasStoredSession = true;

    return result;
  }

  @override
  Future<void> signOut() => session.signOut();

  @override
  Future<bool> hasSession() => session.hasSession();

  @override
  Future<bool> isSecondFactorPending() => session.isSecondFactorPending();

  @override
  Future<void> requestPasswordReset(String email) async {
    passwordResetCalls.add(email);

    final pending = passwordResetPending;
    if (pending != null) await pending.future;

    final error = passwordResetError;
    if (error != null) throw error;
  }
}
