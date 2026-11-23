import 'package:reportaai_cm/features/account/domain/models/user_session.dart';

/// As sessões abertas da conta (RM19). A implementação que chama a API fica em `data/`, e os
/// testes usam um fake.
///
/// Os métodos lançam uma `ApiException` (de `core/network`) quando a API não responde ou responde
/// com erro: a `UnauthorizedException` quando a sessão acabou e a `NetworkException` sem conexão.
abstract interface class SessionsRepository {
  /// As sessões abertas da conta (`GET /api/users/me/sessions`), da mais recente para a mais
  /// antiga, com a deste aparelho marcada no `current`.
  Future<List<UserSession>> list();

  /// Encerra a sessão do [id] (`DELETE /api/users/me/sessions/:id`). O aparelho dela sai na
  /// renovação seguinte, em até 15 minutos. Lança a `NotFoundException` (404) quando a sessão já
  /// tinha acabado.
  Future<void> revoke(String id);

  /// Encerra todas as sessões, menos a deste aparelho (`DELETE /api/users/me/sessions`).
  Future<void> revokeOthers();
}
