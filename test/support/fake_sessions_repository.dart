import 'dart:async';

import 'package:reportaai_cm/features/account/domain/models/user_session.dart';
import 'package:reportaai_cm/features/account/domain/repositories/sessions_repository.dart';

/// A sessão deste aparelho, com o `User-Agent` do app.
final currentSession = UserSession(
  id: 'sessao-deste-aparelho',
  createdAt: DateTime.utc(2026, 11, 20, 12, 30),
  expiresAt: DateTime.utc(2026, 11, 27, 12, 30),
  ipAddress: '203.0.113.10',
  userAgent: 'ReportaAiCm/0.1.0 (Android)',
  current: true,
);

/// Uma sessão aberta pelo navegador, num computador.
final browserSession = UserSession(
  id: 'sessao-do-navegador',
  createdAt: DateTime.utc(2026, 11, 18, 9),
  expiresAt: DateTime.utc(2026, 11, 25, 9),
  ipAddress: '198.51.100.7',
  userAgent: 'Mozilla/5.0 (X11; Linux x86_64)',
  current: false,
);

/// Uma sessão antiga, sem o IP e o user agent.
final unknownSession = UserSession(
  id: 'sessao-antiga',
  createdAt: DateTime.utc(2026, 11, 1, 18),
  expiresAt: DateTime.utc(2026, 11, 8, 18),
  current: false,
);

/// Fake do [SessionsRepository], escrito à mão como o `FakeIdentityProvider` do backend. Cada
/// teste define a lista e os erros das próximas chamadas, e confere as chamadas feitas. O
/// encerramento tira a sessão da lista, como a API.
final class FakeSessionsRepository implements SessionsRepository {
  /// A lista da API, na ordem dela: a mais recente primeiro.
  List<UserSession> sessions = [browserSession, currentSession, unknownSession];

  /// Lançado na próxima listagem.
  Exception? listError;

  /// Enquanto não é completada, a listagem fica pendente.
  Completer<void>? listPending;

  int listCalls = 0;

  /// Lançado no próximo encerramento de uma sessão, como a `NotFoundException` do 404.
  Exception? revokeError;

  /// Enquanto não é completado, o encerramento de uma sessão fica pendente.
  Completer<void>? revokePending;

  final revokeCalls = <String>[];

  /// Lançado no próximo "Encerrar todas as outras".
  Exception? revokeOthersError;

  int revokeOthersCalls = 0;

  @override
  Future<List<UserSession>> list() async {
    listCalls++;

    final pending = listPending;
    if (pending != null) await pending.future;

    final error = listError;
    if (error != null) throw error;

    return List.unmodifiable(sessions);
  }

  @override
  Future<void> revoke(String id) async {
    revokeCalls.add(id);

    final pending = revokePending;
    if (pending != null) await pending.future;

    final error = revokeError;
    if (error != null) throw error;

    sessions = [...sessions.where((session) => session.id != id)];
  }

  @override
  Future<void> revokeOthers() async {
    revokeOthersCalls++;

    final error = revokeOthersError;
    if (error != null) throw error;

    sessions = [...sessions.where((session) => session.current)];
  }
}
