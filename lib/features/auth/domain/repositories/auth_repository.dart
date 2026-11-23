import 'package:reportaai_cm/features/auth/domain/models/sign_in_result.dart';

/// O login e a sessão do usuário. A implementação que chama a API fica em `data/`, e os testes
/// usam um fake.
///
/// Os métodos lançam uma `ApiException` (de `core/network`) quando a API não responde ou responde
/// com um erro que não é um resultado do login, como a `NetworkException` sem conexão.
abstract interface class AuthRepository {
  /// Entra com o [email] e a [password]. O e-mail vai sem os espaços das pontas e em minúsculas,
  /// como a API o guarda (RN02). Com o [SignInSuccess], a sessão já está guardada no aparelho.
  ///
  /// Lança a `NetworkException` sem conexão e a `ServerException` no 5xx ou numa resposta que o
  /// app não conhece.
  Future<SignInResult> signIn({required String email, required String password});

  /// Encerra a sessão na API e a apaga do aparelho. Sem conexão, lança a `NetworkException` e
  /// mantém a sessão (RM10).
  Future<void> signOut();

  /// Se há uma sessão guardada no aparelho. Sem rede para renovar o access token vencido, a
  /// sessão continua valendo: quem decide é a chamada seguinte (RM06).
  Future<bool> hasSession();

  /// Se a sessão está pendente da segunda etapa do login, a verificação em duas etapas (RN25,
  /// RM18). Lança a `UnauthorizedException` quando a sessão acabou e foi apagada, e a
  /// `NetworkException` sem rede para renovar, com a sessão mantida.
  Future<bool> isSecondFactorPending();

  /// Conclui o login com o [code] de 6 dígitos enviado por e-mail (`POST /api/mfa/verify`, com a
  /// sessão pendente). A resposta já traz o access token da sessão completa, que o SDK guarda.
  ///
  /// Lança a `BusinessRuleException` (422, com o `field` igual a `code`) com o código errado,
  /// vencido, já usado ou invalidado por 5 erros: a API dá a mesma mensagem nos quatro casos. Lança
  /// a `ValidationException` com o código fora do formato e a `NetworkException` sem conexão.
  Future<void> verifyLoginCode(String code);

  /// Envia um código novo, que invalida o anterior (`POST /api/mfa/code`, com a sessão pendente).
  /// Lança a `BusinessRuleException` (422) quando o último código saiu há menos de 1 minuto.
  Future<void> resendLoginCode();

  /// "Esqueci minha senha": pede o link para criar uma senha nova (`POST /api/password-resets`,
  /// público), com o [email] sem os espaços das pontas e em minúsculas (RN02). A API responde do
  /// mesmo jeito com ou sem conta (RN20), e o método termina sem dizer qual foi o caso.
  ///
  /// Lança a `ValidationException` com o e-mail fora do formato, a `RateLimitException` no limite
  /// por IP, a `NetworkException` sem conexão e a `ServerException` no 5xx.
  Future<void> requestPasswordReset(String email);
}
