import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/account/account_providers.dart';
import 'package:reportaai_cm/features/account/domain/models/user_session.dart';

/// Estado da tela "Sessões abertas": a lista, o carregamento, o erro dele e as sessões sendo
/// encerradas.
final NotifierProvider<SessionsViewModel, SessionsState> sessionsViewModelProvider =
    NotifierProvider.autoDispose(SessionsViewModel.new);

@immutable
final class SessionsState {
  const new({
    this.sessions,
    this.isLoading = false,
    this.loadError,
    this.revokingIds = const {},
    this.isRevokingOthers = false,
  });

  /// As sessões, com a deste aparelho primeiro. `null` até a primeira lista chegar.
  final List<UserSession>? sessions;

  final bool isLoading;

  /// A mensagem do último carregamento que falhou. Com uma lista já na tela, ela continua.
  final String? loadError;

  /// As sessões com o "Encerrar" em andamento.
  final Set<String> revokingIds;

  final bool isRevokingOthers;

  /// Se há outras sessões além da deste aparelho, para o "Encerrar todas as outras".
  bool get hasOtherSessions => sessions?.any((session) => !session.current) ?? false;

  @override
  bool operator ==(Object other) =>
      other is SessionsState &&
      listEquals(other.sessions, sessions) &&
      other.isLoading == isLoading &&
      other.loadError == loadError &&
      setEquals(other.revokingIds, revokingIds) &&
      other.isRevokingOthers == isRevokingOthers;

  @override
  int get hashCode => Object.hash(
    sessions == null ? null : Object.hashAll(sessions!),
    isLoading,
    loadError,
    Object.hashAllUnordered(revokingIds),
    isRevokingOthers,
  );

  @override
  String toString() =>
      'SessionsState(sessions: $sessions, isLoading: $isLoading, loadError: $loadError, '
      'revokingIds: $revokingIds, isRevokingOthers: $isRevokingOthers)';
}

/// Lista e encerra as sessões abertas da conta (RM19). A deste aparelho vem primeiro e não tem o
/// "Encerrar": para sair dela, o "Sair".
final class SessionsViewModel extends Notifier<SessionsState> {
  static const revokedMessage = 'Sessão encerrada. O aparelho sai da conta em até 15 minutos.';
  static const othersRevokedMessage =
      'As outras sessões foram encerradas. Os aparelhos saem da conta em até 15 minutos.';

  @override
  SessionsState build() {
    unawaited(Future.microtask(load));
    return const SessionsState(isLoading: true);
  }

  /// Busca a lista, na abertura da tela, no "Tentar de novo" e no puxar para atualizar. Com uma
  /// lista já na tela, ela continua durante a busca e se a busca falhar.
  Future<void> load() async {
    // A tela pode ter fechado antes da primeira busca começar.
    if (!ref.mounted) return;

    state = _copy(isLoading: true, loadError: null);

    List<UserSession>? sessions;
    String? loadError;
    try {
      sessions = _currentFirst(await ref.read(sessionsRepositoryProvider).list());
    } on Object catch (error) {
      loadError = ApiException.messageOf(error);
    }

    // A tela pode ter fechado enquanto a lista esperava a API.
    if (!ref.mounted) return;

    state = _copy(sessions: sessions, isLoading: false, loadError: loadError);
  }

  /// "Encerrar" a sessão do [id]: some da lista, também quando já tinha acabado (404). Devolve a
  /// mensagem para a tela mostrar, de sucesso ou de erro.
  Future<String> revoke(String id) async {
    if (state.revokingIds.contains(id)) return revokedMessage;

    state = _copy(revokingIds: {...state.revokingIds, id});

    String message;
    var removed = true;
    try {
      await ref.read(sessionsRepositoryProvider).revoke(id);
      message = revokedMessage;
    } on NotFoundException {
      // A sessão já tinha acabado: o resultado é o mesmo.
      message = revokedMessage;
    } on Object catch (error) {
      message = ApiException.messageOf(error);
      removed = false;
    }

    if (ref.mounted) {
      state = _copy(
        sessions: removed
            ? [...?state.sessions?.where((session) => session.id != id)]
            : state.sessions,
        revokingIds: {...state.revokingIds}..remove(id),
      );
    }
    return message;
  }

  /// "Encerrar todas as outras": só a sessão deste aparelho fica na lista. Devolve a mensagem para
  /// a tela mostrar, de sucesso ou de erro.
  Future<String> revokeOthers() async {
    if (state.isRevokingOthers) return othersRevokedMessage;

    state = _copy(isRevokingOthers: true);

    String message;
    var revoked = true;
    try {
      await ref.read(sessionsRepositoryProvider).revokeOthers();
      message = othersRevokedMessage;
    } on Object catch (error) {
      message = ApiException.messageOf(error);
      revoked = false;
    }

    if (ref.mounted) {
      state = _copy(
        sessions: revoked
            ? [...?state.sessions?.where((session) => session.current)]
            : state.sessions,
        isRevokingOthers: false,
      );
    }
    return message;
  }

  /// O estado de agora com os campos passados trocados. O `loadError` passado como `null` sai.
  SessionsState _copy({
    List<UserSession>? sessions,
    bool? isLoading,
    Object? loadError = _keep,
    Set<String>? revokingIds,
    bool? isRevokingOthers,
  }) => SessionsState(
    sessions: sessions ?? state.sessions,
    isLoading: isLoading ?? state.isLoading,
    loadError: identical(loadError, _keep) ? state.loadError : loadError as String?,
    revokingIds: revokingIds ?? state.revokingIds,
    isRevokingOthers: isRevokingOthers ?? state.isRevokingOthers,
  );
}

/// Marca o campo que o `_copy` mantém como está.
const _keep = Object();

/// A sessão deste aparelho primeiro, e as outras na ordem da API, da mais recente para a mais
/// antiga.
List<UserSession> _currentFirst(List<UserSession> sessions) => List.unmodifiable([
  ...sessions.where((session) => session.current),
  ...sessions.where((session) => !session.current),
]);
