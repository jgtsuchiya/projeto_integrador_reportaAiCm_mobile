/// Caminhos das rotas do app, em português, como aparecem nos deep links.
abstract final class AppRoutes {
  /// Tela de abertura: o carregando enquanto o app confere a sessão, e o erro sem rede (RM06).
  static const splash = '/abertura';

  /// Login, para quem não tem sessão.
  static const login = '/login';

  /// Cadastro do Client. Rota pública: abre sem sessão (RM11 e RM12).
  static const register = '/cadastro';

  /// "Esqueci minha senha". Rota pública: abre sem sessão (RM13).
  static const forgotPassword = '/esqueci-senha';

  /// Tela inicial, a primeira com a sessão aberta.
  static const home = '/inicio';

  /// Diagnóstico da conexão com a API. Só existe em debug.
  static const diagnostics = '/diagnostico';

  /// As rotas que abrem sem sessão, além do login, como o `@Public()` do backend. Com o Client
  /// dentro, elas levam à tela inicial.
  static const Set<String> public = {register, forgotPassword};
}
