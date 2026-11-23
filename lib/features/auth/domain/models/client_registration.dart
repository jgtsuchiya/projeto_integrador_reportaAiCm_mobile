import 'package:meta/meta.dart';

/// Os campos do cadastro do Client, para a mensagem de erro de cada um. O [apiName] é o nome do
/// campo no corpo do `POST /api/clients` e no `details` dos erros da API.
enum RegistrationField {
  name('name'),
  email('email'),
  password('password'),
  cpf('cpf'),
  phone('phone'),
  birthDate('birthDate');

  new(this.apiName);

  final String apiName;

  /// O campo com o [apiName], ou `null` para um campo que o app não conhece.
  static RegistrationField? fromApiName(String? apiName) {
    for (final field in values) {
      if (field.apiName == apiName) return field;
    }
    return null;
  }
}

/// Os dados do cadastro do Client (`POST /api/clients`), já no formato da API: o [cpf] e o
/// [phone] só com os dígitos e a [birthDate] em `AAAA-MM-DD`. O nome e o e-mail vão como foram
/// digitados: quem os envia tira os espaços das pontas e põe o e-mail em minúsculas (RN02).
@immutable
final class ClientRegistration {
  const new({
    required this.name,
    required this.email,
    required this.password,
    required this.cpf,
    required this.phone,
    required this.birthDate,
  });

  final String name;
  final String email;

  /// Como foi digitada. Nunca vai para log (RM09).
  final String password;

  /// Só com os dígitos. Nunca vai para log (RM09).
  final String cpf;

  /// Só com os dígitos: o DDD e o número.
  final String phone;

  /// `AAAA-MM-DD`.
  final String birthDate;

  @override
  bool operator ==(Object other) =>
      other is ClientRegistration &&
      other.name == name &&
      other.email == email &&
      other.password == password &&
      other.cpf == cpf &&
      other.phone == phone &&
      other.birthDate == birthDate;

  @override
  int get hashCode => Object.hash(name, email, password, cpf, phone, birthDate);

  @override
  String toString() =>
      // A senha e o CPF nunca vão para log (RM09).
      'ClientRegistration(name: $name, email: $email, password: ***, cpf: ***, phone: $phone, '
      'birthDate: $birthDate)';
}
