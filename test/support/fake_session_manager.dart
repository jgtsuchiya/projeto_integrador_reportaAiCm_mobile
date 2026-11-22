import 'dart:async';

import 'package:reportaai_cm/core/auth/session_manager.dart';

/// Fake do [SessionManager], escrito à mão como o `FakeIdentityProvider` do backend. Cada teste
/// define a sessão e os erros das próximas chamadas, e simula o fim da sessão com o [expire].
final class FakeSessionManager implements SessionManager {
  /// Se há uma sessão guardada. O [signOut] e o [expire] a apagam.
  bool hasStoredSession = false;

  /// A resposta do [isSecondFactorPending] (RM08).
  bool secondFactorPending = false;

  /// Lançado na próxima chamada do [isSecondFactorPending], como a renovação da sessão sem rede
  /// (`NetworkException`) ou recusada pela API (`UnauthorizedException`).
  Exception? secondFactorError;

  /// Lançado na próxima chamada do [signOut], como sem conexão (RM10). A sessão continua.
  Exception? signOutError;

  /// Enquanto não é completado, o [signOut] fica pendente: é o "Sair" em andamento.
  Completer<void>? signOutPending;

  int signOutCalls = 0;

  final _events = StreamController<SessionEvent>.broadcast();

  @override
  Stream<SessionEvent> get events => _events.stream;

  /// A sessão acabou fora do app (RM07), como o `UNAUTHORISED` do SDK: apaga a sessão e avisa.
  void expire() {
    hasStoredSession = false;
    _events.add(SessionEvent.expired);
  }

  @override
  Future<bool> hasSession() async => hasStoredSession;

  @override
  Future<bool> isSecondFactorPending() async {
    final error = secondFactorError;
    if (error != null) throw error;

    return secondFactorPending;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;

    final pending = signOutPending;
    if (pending != null) await pending.future;

    final error = signOutError;
    if (error != null) throw error;

    hasStoredSession = false;
    _events.add(SessionEvent.signedOut);
  }
}
