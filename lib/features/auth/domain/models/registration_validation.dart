import 'package:reportaai_cm/features/auth/domain/models/birth_date.dart';
import 'package:reportaai_cm/features/auth/domain/models/client_registration.dart';
import 'package:reportaai_cm/features/auth/domain/models/cpf.dart';
import 'package:reportaai_cm/features/auth/domain/models/email.dart';
import 'package:reportaai_cm/features/auth/domain/models/password.dart';
import 'package:reportaai_cm/features/auth/domain/models/phone.dart';
import 'package:reportaai_cm/features/auth/domain/models/user_name.dart';

/// As mensagens dos campos do cadastro (RM11). Fora do campo vazio, são as da API (as do
/// `register-client.dto.spec.ts` do backend), para a tela mostrar a mesma mensagem que a API
/// mandaria. Duas mudam:
///
/// - o campo vazio pede o campo ("Informe o CPF."), como no login, em vez de dizer que ele é
///   inválido;
/// - a data fora do formato pede o formato da tela (`DD/MM/AAAA`), e não o da API.
abstract final class RegistrationMessages {
  static const nameMissing = 'Informe o nome.';
  static const nameTooLong = 'O nome deve ter no máximo $userNameMaxLength caracteres.';
  static const cpfMissing = 'Informe o CPF.';
  static const cpfInvalid = 'CPF inválido.';
  static const phoneMissing = 'Informe o telefone.';
  static const phoneInvalid = 'Telefone inválido. Informe o DDD e o número.';
  static const birthDateMissing = 'Informe a data de nascimento.';
  static const birthDateInvalid = 'Data de nascimento inválida. Use o formato DD/MM/AAAA.';
  static const birthDateNotInPast = 'A data de nascimento precisa estar no passado.';
}

/// A conferência do cadastro antes de enviar (RM11), com as regras dos value objects da API.
///
/// Recebe os campos como estão na tela, com a máscara (o CPF e o telefone a API também aceita
/// assim), menos a [birthDate], que vem em `AAAA-MM-DD`. Devolve o erro de cada campo recusado,
/// ou um mapa vazio quando o cadastro pode ser enviado. O [now] decide o "hoje" da data de
/// nascimento.
Map<RegistrationField, String> validateRegistration({
  required String name,
  required String email,
  required String password,
  required String cpf,
  required String phone,
  required String birthDate,
  DateTime? now,
}) => {
  if (name.trim().isEmpty)
    RegistrationField.name: RegistrationMessages.nameMissing
  else if (!isValidUserName(name))
    RegistrationField.name: RegistrationMessages.nameTooLong,
  RegistrationField.email: ?validateEmail(email),
  if (password.isEmpty)
    RegistrationField.password: PasswordMessages.missing
  else
    RegistrationField.password: ?validatePassword(password),
  if (cpf.trim().isEmpty)
    RegistrationField.cpf: RegistrationMessages.cpfMissing
  else if (!isValidCpf(cpf))
    RegistrationField.cpf: RegistrationMessages.cpfInvalid,
  if (phone.trim().isEmpty)
    RegistrationField.phone: RegistrationMessages.phoneMissing
  else if (!isValidPhone(phone))
    RegistrationField.phone: RegistrationMessages.phoneInvalid,
  if (birthDate.trim().isEmpty)
    RegistrationField.birthDate: RegistrationMessages.birthDateMissing
  else if (!isCalendarDate(birthDate))
    RegistrationField.birthDate: RegistrationMessages.birthDateInvalid
  else if (!isValidBirthDate(birthDate, now: now))
    RegistrationField.birthDate: RegistrationMessages.birthDateNotInPast,
};
