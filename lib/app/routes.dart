/// Caminhos das rotas do app, em português, como aparecem nos deep links.
abstract final class AppRoutes {
  /// Tela inicial. Provisória até o épico de login, que a troca pela tela com os dados do usuário.
  static const home = '/inicio';

  /// Diagnóstico da conexão com a API. Só existe em debug.
  static const diagnostics = '/diagnostico';
}
