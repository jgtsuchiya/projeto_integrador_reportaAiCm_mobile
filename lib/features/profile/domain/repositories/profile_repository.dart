import 'package:reportaai_cm/features/profile/domain/models/user_profile.dart';

/// O perfil do usuário logado. A implementação que chama a API fica em `data/`, e os testes usam
/// um fake.
abstract interface class ProfileRepository {
  /// O perfil e o papel de quem está logado (`GET /api/users/me`). Lança uma `ApiException` (de
  /// `core/network`) quando a API não responde ou responde com erro: a `UnauthorizedException`
  /// quando a sessão acabou, a `SecondFactorPendingException` com a sessão pendente da segunda
  /// etapa e a `NetworkException` sem conexão.
  Future<UserProfile> getMe();
}
