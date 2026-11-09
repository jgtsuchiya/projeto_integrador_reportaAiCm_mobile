/// Caminhos das rotas do app, em português, como aparecem nos deep links.
abstract final class AppRoutes {
  /// Tela de abertura: o carregando enquanto o app confere a sessão, e o erro sem rede (RM06).
  static const splash = '/abertura';

  /// Login, para quem não tem sessão.
  static const login = '/login';

  /// Tela inicial, a primeira com a sessão aberta.
  static const home = '/inicio';

  /// Diagnóstico da conexão com a API. Só existe em debug.
  static const diagnostics = '/diagnostico';
}
