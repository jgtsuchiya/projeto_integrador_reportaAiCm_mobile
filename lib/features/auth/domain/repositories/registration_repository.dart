import 'package:reportaai_cm/features/auth/domain/models/client_registration.dart';
import 'package:reportaai_cm/features/auth/domain/models/registration_result.dart';

/// O autocadastro do Client. A implementação que chama a API fica em `data/`, e os testes usam um
/// fake.
abstract interface class RegistrationRepository {
  /// Cria a conta do Client com a [registration] (`POST /api/clients`, público). Com o
  /// [RegistrationSuccess], a conta existe, mas a sessão não foi aberta: falta o login.
  ///
  /// Lança a `NetworkException` sem conexão e a `ServerException` no 5xx ou numa resposta que o
  /// app não conhece. Um 400 ou um 409 sem um campo que o app conheça sai como a
  /// `ValidationException` ou a `ConflictException`, com a mensagem geral da API.
  Future<RegistrationResult> register(ClientRegistration registration);
}
