import 'dart:async';

import 'package:reportaai_cm/features/auth/domain/models/sign_in_result.dart';
import 'package:reportaai_cm/features/auth/domain/repositories/auth_repository.dart';

import 'fake_session_manager.dart';

/// Fake do [AuthRepository], escrito à mão como o `FakeIdentityProvider` do backend. Cada teste
/// define o resultado do próximo login e confere os logins feitos em [signInCalls].
///
/// A sessão fica no [session]: o login com sucesso a abre, o código certo da segunda etapa a
/// completa, e o [hasSession], o [isSecondFactorPending] e o [signOut] vão para ela, como no
/// `ApiAuthRepository`. Para o
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

  /// Lançado na próxima conferência do código da segunda etapa, como a `BusinessRuleException`
  /// do código errado. Sem ele, o código conclui o login: a sessão deixa de estar pendente.
  Exception? verifyLoginCodeError;

  /// Enquanto não é completado, a conferência do código fica pendente.
  Completer<void>? verifyLoginCodePending;

  /// Os códigos conferidos, na ordem.
  final verifyLoginCodeCalls = <String>[];

  /// Lançado no próximo reenvio do código, como a `BusinessRuleException` do envio recente.
  Exception? resendLoginCodeError;

  int resendLoginCodeCalls = 0;

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
  Future<void> verifyLoginCode(String code) async {
    verifyLoginCodeCalls.add(code);

    final pending = verifyLoginCodePending;
    if (pending != null) await pending.future;

    final error = verifyLoginCodeError;
    if (error != null) throw error;

    session.secondFactorPending = false;
  }

  @override
  Future<void> resendLoginCode() async {
    resendLoginCodeCalls++;

    final error = resendLoginCodeError;
    if (error != null) throw error;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    passwordResetCalls.add(email);

    final pending = passwordResetPending;
    if (pending != null) await pending.future;

    final error = passwordResetError;
    if (error != null) throw error;
  }
}
