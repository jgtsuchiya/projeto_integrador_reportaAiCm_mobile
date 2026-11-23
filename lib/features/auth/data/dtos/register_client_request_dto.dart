import 'package:reportaai_cm/features/auth/domain/models/client_registration.dart';
import 'package:reportaai_cm/features/auth/domain/models/email.dart';

/// O corpo do `POST /api/clients`: `{ name, email, password, cpf, phone, birthDate }`.
final class RegisterClientRequestDto {
  const new(this.registration);

  final ClientRegistration registration;

  /// O nome vai sem os espaços das pontas, e o e-mail, também em minúsculas, como a API os guarda
  /// (RN02). A senha vai como foi digitada, o CPF e o telefone só com os dígitos, e a data em
  /// `AAAA-MM-DD`, como já estão na [registration].
  Map<String, Object?> toJson() => {
    'name': registration.name.trim(),
    'email': normalizeEmail(registration.email),
    'password': registration.password,
    'cpf': registration.cpf,
    'phone': registration.phone,
    'birthDate': registration.birthDate,
  };
}
