import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/sessions_view_model.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_sessions_repository.dart';

void main() {
  group('SessionsViewModel', () {
    late AuthFakes fakes;
    late ProviderContainer container;

    setUp(() {
      fakes = AuthFakes(signedIn: true);
      container = ProviderContainer.test(overrides: fakes.overrides, retry: noAutomaticRetry);
    });

    /// Abre a tela e espera a primeira lista.
    Future<void> open() async {
      container.listen(sessionsViewModelProvider, (_, _) {});
      await pumpEventQueue();
    }

    SessionsViewModel sut() => container.read(sessionsViewModelProvider.notifier);
    SessionsState state() => container.read(sessionsViewModelProvider);

    test('deve carregar a lista, com a sessão deste aparelho primeiro (RM19)', () async {
      container.listen(sessionsViewModelProvider, (_, _) {});
      expect(state(), const SessionsState(isLoading: true));

      await pumpEventQueue();

      expect(state().sessions, [currentSession, browserSession, unknownSession]);
      expect(state().isLoading, isFalse);
      expect(state().hasOtherSessions, isTrue);
    });

    test('deve mostrar o erro da primeira lista e carregar no "Tentar de novo"', () async {
      fakes.sessions.listError = const NetworkException();
      await open();

      expect(state().sessions, isNull);
      expect(state().loadError, NetworkException.defaultMessage);

      fakes.sessions.listError = null;
      await sut().load();

      expect(state().loadError, isNull);
      expect(state().sessions, hasLength(3));
    });

    test('deve manter a lista quando a atualização falha', () async {
      await open();
      fakes.sessions.listError = const NetworkException();

      await sut().load();

      expect(state().sessions, hasLength(3));
      expect(state().loadError, NetworkException.defaultMessage);
    });

    test('deve encerrar uma sessão e tirá-la da lista', () async {
      await open();
      final pending = fakes.sessions.revokePending = Completer<void>();

      final revoke = sut().revoke(browserSession.id);
      await pumpEventQueue();
      expect(state().revokingIds, {browserSession.id});
      pending.complete();
      final message = await revoke;

      expect(message, SessionsViewModel.revokedMessage);
      expect(fakes.sessions.revokeCalls, [browserSession.id]);
      expect(state().sessions, [currentSession, unknownSession]);
      expect(state().revokingIds, isEmpty);
    });

    test('deve tirar da lista, sem erro, a sessão que já tinha acabado (404)', () async {
      await open();
      fakes.sessions.revokeError = const NotFoundException();

      final message = await sut().revoke(unknownSession.id);

      expect(message, SessionsViewModel.revokedMessage);
      expect(state().sessions, [currentSession, browserSession]);
    });

    test('deve manter a sessão e devolver o erro sem conexão', () async {
      await open();
      fakes.sessions.revokeError = const NetworkException();

      final message = await sut().revoke(browserSession.id);

      expect(message, NetworkException.defaultMessage);
      expect(state().sessions, hasLength(3));
      expect(state().revokingIds, isEmpty);
    });

    test('deve ignorar o "Encerrar" repetido da mesma sessão', () async {
      await open();
      final pending = fakes.sessions.revokePending = Completer<void>();

      final first = sut().revoke(browserSession.id);
      await pumpEventQueue();
      await sut().revoke(browserSession.id);
      pending.complete();
      await first;

      expect(fakes.sessions.revokeCalls, hasLength(1));
    });

    test('deve encerrar todas as outras e deixar só a deste aparelho', () async {
      await open();

      final message = await sut().revokeOthers();

      expect(message, SessionsViewModel.othersRevokedMessage);
      expect(fakes.sessions.revokeOthersCalls, 1);
      expect(state().sessions, [currentSession]);
      expect(state().hasOtherSessions, isFalse);
      expect(state().isRevokingOthers, isFalse);
    });

    test('deve manter as outras e devolver o erro quando o encerramento falha', () async {
      await open();
      fakes.sessions.revokeOthersError = const NetworkException();

      final message = await sut().revokeOthers();

      expect(message, NetworkException.defaultMessage);
      expect(state().sessions, hasLength(3));
    });

    test('deve ignorar o "Encerrar todas as outras" durante outro', () async {
      await open();
      final first = sut().revokeOthers();
      final second = await sut().revokeOthers();
      await first;

      expect(second, SessionsViewModel.othersRevokedMessage);
      expect(fakes.sessions.revokeOthersCalls, 1);
    });

    test('deve descartar a lista quando a tela fecha durante a busca', () async {
      final pending = fakes.sessions.listPending = Completer<void>();
      final screen = container.listen(sessionsViewModelProvider, (_, _) {});
      await pumpEventQueue();

      screen.close();
      await pumpEventQueue();
      pending.complete();
      await pumpEventQueue();

      // Sem erro: o estado da tela fechada não muda.
      expect(fakes.sessions.listCalls, 1);
    });

    test('deve comparar o estado pelo valor', () {
      final a = SessionsState(sessions: [currentSession], revokingIds: const {'x'});
      final b = SessionsState(sessions: [currentSession], revokingIds: const {'x'});

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('revokingIds: {x}'));
      expect(const SessionsState().hasOtherSessions, isFalse);
    });
  });
}
