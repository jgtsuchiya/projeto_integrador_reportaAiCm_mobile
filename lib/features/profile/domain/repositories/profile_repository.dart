import 'package:reportaai_cm/features/profile/domain/models/profile_changes.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_profile.dart';

/// O perfil do usuário logado. A implementação que chama a API fica em `data/`, e os testes usam
/// um fake.
///
/// Os métodos lançam uma `ApiException` (de `core/network`) quando a API não responde ou responde
/// com erro: a `UnauthorizedException` quando a sessão acabou, a `NetworkException` sem conexão e
/// a `ServerException` no 5xx.
abstract interface class ProfileRepository {
  /// O perfil e o papel de quem está logado (`GET /api/users/me`). Lança a
  /// `SecondFactorPendingException` com a sessão pendente da segunda etapa.
  Future<UserProfile> getMe();

  /// Reenvia o link de confirmação do e-mail de quem está logado
  /// (`POST /api/users/me/email-verification`). O link novo substitui os anteriores (RN22).
  ///
  /// Lança a `BusinessRuleException` (422) quando o e-mail já foi confirmado, ou quando o último
  /// e-mail saiu há menos de 1 minuto: a `message` da API diz qual dos dois.
  Future<void> resendEmailVerification();

  /// Salva os dados que o Client mudou (`PATCH /api/users/me`), só os campos das [changes], e
  /// devolve o perfil atualizado. Lança a `ValidationException` (400) com o erro de cada campo.
  Future<UserProfile> updateMe(ProfileChanges changes);

  /// Troca a senha (`PATCH /api/users/me/password`). A sessão deste aparelho continua, e as outras
  /// saem na renovação seguinte (RN13).
  ///
  /// Lança a `BusinessRuleException` (422, com o `field` igual a `currentPassword`) com a senha
  /// atual incorreta, e a `ValidationException` (400) com a senha nova fora da política (RN08).
  Future<void> changePassword({required String currentPassword, required String newPassword});

  /// Liga ou desliga a verificação em duas etapas (`PATCH /api/users/me/mfa`), confirmada com a
  /// [password] atual, e devolve o perfil atualizado. Ativar encerra as outras sessões (RN24).
  ///
  /// Lança a `BusinessRuleException` (422): com o `field` igual a `password`, a senha incorreta;
  /// sem o campo, a ativação com o e-mail ainda não confirmado.
  Future<UserProfile> setMfa({required bool enabled, required String password});

  /// Exclui a conta do Client (`DELETE /api/users/me`), confirmada com a [password] atual: os
  /// dados pessoais são apagados e as sessões acabam em todos os aparelhos (RN11 e RN15). Os
  /// tokens continuam no aparelho: quem chama apaga a sessão em seguida.
  ///
  /// Lança a `BusinessRuleException` (422, com o `field` igual a `password`) com a senha
  /// incorreta.
  Future<void> deleteAccount({required String password});
}
