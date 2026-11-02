import 'dart:async';

import 'package:reportaai_cm/core/auth/session_manager.dart';
import 'package:reportaai_cm/core/config/app_config.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:supertokens_flutter/supertokens.dart';

/// Base das rotas do SuperTokens na API (signin, renovação e saída).
const authBasePath = '/api/auth';

/// A claim de sessão da segunda etapa do login, gravada pela API no access token (RN25).
const secondFactorClaimKey = 'mfa-verified';

/// O [SessionManager] do app, com o SDK do SuperTokens no modo header: o access token vai no
/// `Authorization`, e o SDK guarda os tokens que voltam nos headers das respostas.
///
/// O SDK é global: ele é inicializado uma vez, pelo [SuperTokensSessionManager.initialize], no
/// `main`, antes do `runApp`. O interceptor dele entra no `Dio` pelo `sessionInterceptors`.
final class SuperTokensSessionManager implements SessionManager {
  /// Inicializa o SDK com a API do [config] e devolve o [SessionManager] ligado aos eventos dele.
  /// O SDK só aceita a primeira inicialização: as chamadas seguintes devolvem a mesma instância.
  factory initialize(AppConfig config) => _instance ??= SuperTokensSessionManager._(config);

  new _(AppConfig config) {
    SuperTokens.init(
      apiDomain: config.apiUrl,
      apiBasePath: authBasePath,
      tokenTransferMethod: SuperTokensTokenTransferMethod.HEADER,
      eventHandler: _onSdkEvent,
      // O log do SDK mostra os tokens (RM09): fica desligado também em debug.
      enableDebugLogs: false,
    );
  }

  static SuperTokensSessionManager? _instance;

  final _events = StreamController<SessionEvent>.broadcast();

  @override
  Stream<SessionEvent> get events => _events.stream;

  @override
  Future<bool> hasSession() async {
    // Sem rede para renovar o access token vencido, o SDK responde `false` e mantém os tokens.
    return await SuperTokens.doesSessionExist() || await _isStored();
  }

  @override
  Future<bool> isSecondFactorPending() async {
    final Map<String, dynamic> payload;
    try {
      payload = await SuperTokens.getAccessTokenPayloadSecurely();
    } on SuperTokensException {
      // Sem sessão, ou a renovação do access token vencido falhou.
      throw await _sessionFailure();
    }

    return isSecondFactorPendingIn(payload);
  }

  @override
  Future<void> signOut() async {
    // O SDK não lança erro, e o erro do completionHandler não basta: com o access token vencido
    // e sem rede para renovar, ele termina sem erro e sem chamar a API. Quem diz se a saída
    // aconteceu é a sessão guardada, que o SDK só apaga quando a API responde (RM10).
    await SuperTokens.signOut();

    if (await _isStored()) throw const NetworkException();
  }

  void _onSdkEvent(Eventype event) {
    switch (event) {
      case Eventype.UNAUTHORISED:
        _events.add(SessionEvent.expired);
      case Eventype.SIGN_OUT:
        // O SDK avisa a saída mesmo quando o signOut não chegou à API e os tokens continuam.
        unawaited(_onSignOut());
      case Eventype.SESSION_CREATED ||
          Eventype.REFRESH_SESSION ||
          Eventype.ACCESS_TOKEN_PAYLOAD_UPDATED:
      // O app não depende da criação nem da renovação da sessão: o login e as chamadas seguem.
    }
  }

  Future<void> _onSignOut() async {
    if (!await _isStored()) _events.add(SessionEvent.signedOut);
  }

  /// A renovação da sessão falhou. Se o SDK apagou os tokens, a API recusou a sessão: ela
  /// acabou. Se não, a API não respondeu, e a sessão continua guardada, para tentar de novo.
  Future<ApiException> _sessionFailure() async =>
      await _isStored() ? const NetworkException() : const UnauthorizedException();
}

/// Se a claim da segunda etapa no [payload] do access token marca a sessão como pendente. Sem
/// a claim, a sessão não está pendente.
bool isSecondFactorPendingIn(Map<String, dynamic> payload) =>
    switch (payload[secondFactorClaimKey]) {
      {'v': false} => true,
      _ => false,
    };

/// Se há tokens guardados no aparelho, sem chamar a API nem conferir a validade. O `getUserId`
/// do SDK só lê o front token guardado.
Future<bool> _isStored() async {
  try {
    await SuperTokens.getUserId();
    return true;
  } on SuperTokensException {
    return false;
  }
}
