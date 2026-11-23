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

  /// Código da verificação em duas etapas, com a sessão pendente da segunda etapa (RM18). É a única
  /// tela que a sessão pendente abre.
  static const secondFactor = '/verificacao';

  /// Tela inicial, a primeira com a sessão aberta.
  static const home = '/inicio';

  /// "Minha conta": os dados e as entradas das telas abaixo, abertas por cima dela.
  static const account = '/conta';

  /// Edição do nome, do telefone e da data de nascimento.
  static const accountDetails = '/conta/dados';

  /// Troca de senha (RM15 e RM16).
  static const accountPassword = '/conta/senha';

  /// Sessões abertas em outros aparelhos (RM19).
  static const accountSessions = '/conta/sessoes';

  /// Ativar e desativar a verificação em duas etapas (RM15).
  static const accountSecondFactor = '/conta/verificacao';

  /// Exclusão da conta (RM15 e RM17).
  static const accountDeletion = '/conta/excluir';

  /// "Meus reportes": os reportes do cidadão, com o filtro por status.
  static const reports = '/reportes';

  /// "Novo reporte": a câmera, a localização e o envio (RM20 a RM24). Declarada antes do detalhe,
  /// para `novo` não ser lido como um id.
  static const newReport = '/reportes/novo';

  /// O detalhe do reporte [id].
  static String reportDetail(String id) => '$reports/${Uri.encodeComponent(id)}';

  /// A edição da descrição e da foto do reporte [id] (RM25).
  static String reportEdit(String id) => '${reportDetail(id)}/editar';

  /// Diagnóstico da conexão com a API. Só existe em debug.
  static const diagnostics = '/diagnostico';

  /// As rotas que abrem sem sessão, além do login, como o `@Public()` do backend. Com o Client
  /// dentro, elas levam à tela inicial.
  static const Set<String> public = {register, forgotPassword};
}
