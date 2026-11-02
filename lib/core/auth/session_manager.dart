/// O que muda na sessão sem o app pedir, avisado pelo [SessionManager.events].
enum SessionEvent {
  /// A sessão acabou e não renova mais: refresh token vencido, usuário inativado, sessão
  /// encerrada em outro aparelho ou senha trocada (RM07).
  expired,

  /// O usuário saiu: a sessão foi encerrada na API e os tokens foram apagados do aparelho.
  signedOut,
}

/// A sessão do usuário no aparelho, guardada, enviada e renovada pelo SDK do SuperTokens. É o
/// papel do `IdentityProvider` do backend: só o `core/auth/` conhece o SDK, e o resto do app
/// depende deste contrato.
///
/// O login não passa por aqui: ele é uma chamada à API pelo `Dio`, e o interceptor do SDK guarda
/// a sessão que volta na resposta.
///
/// Os métodos que dependem da API lançam as `ApiException` do `core/network`:
///
/// - `UnauthorizedException`: a API recusou a sessão, e ela foi apagada do aparelho;
/// - `NetworkException`: a API não respondeu, e a sessão continua guardada, para tentar de novo.
abstract interface class SessionManager {
  /// Se há uma sessão guardada no aparelho. Com o access token vencido, tenta renovar antes. Sem
  /// rede para renovar, a sessão continua valendo: quem decide é a chamada seguinte (RM06).
  Future<bool> hasSession();

  /// Se a sessão está pendente da segunda etapa do login, a verificação em duas etapas (RN25):
  /// a claim `mfa-verified` do access token com `v` igual a `false`.
  Future<bool> isSecondFactorPending();

  /// Encerra a sessão na API e apaga os tokens do aparelho. Sem resposta da API, lança a
  /// `NetworkException` e mantém a sessão (RM10).
  Future<void> signOut();

  /// Os [SessionEvent], enquanto o app estiver aberto. O mesmo evento pode chegar mais de uma vez,
  /// e o `expired` também chega quando uma chamada autenticada é feita sem sessão: quem ouve
  /// ignora o que não muda o estado atual.
  Stream<SessionEvent> get events;
}
