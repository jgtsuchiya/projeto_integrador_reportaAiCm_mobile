import 'package:meta/meta.dart';
import 'package:reportaai_cm/features/auth/domain/models/birth_date.dart';
import 'package:reportaai_cm/features/auth/domain/models/phone.dart';
import 'package:reportaai_cm/features/auth/domain/models/registration_validation.dart';
import 'package:reportaai_cm/features/auth/domain/models/user_name.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_profile.dart';

/// Os campos que o Client edita nos próprios dados (`PATCH /api/users/me`). O [apiName] é o nome
/// do campo no corpo e no `details` dos erros da API. O e-mail e o CPF não mudam.
enum ProfileField {
  name('name'),
  phone('phone'),
  birthDate('birthDate');

  new(this.apiName);

  final String apiName;

  /// O campo com o [apiName], ou `null` para um campo que o app não conhece.
  static ProfileField? fromApiName(String? apiName) {
    for (final field in values) {
      if (field.apiName == apiName) return field;
    }
    return null;
  }
}

/// O que muda nos dados do Client, no formato da API: só os campos que mudaram, e `null` nos
/// outros. O [phone] vai só com os dígitos, e a [birthDate] em `AAAA-MM-DD`. O [name] vai como foi
/// digitado: quem o envia tira os espaços das pontas.
@immutable
final class ProfileChanges {
  const new({this.name, this.phone, this.birthDate});

  final String? name;
  final String? phone;
  final String? birthDate;

  /// Se nada mudou: o "Salvar" fica desativado, e a API não é chamada (ela recusa o corpo vazio).
  bool get isEmpty => name == null && phone == null && birthDate == null;

  @override
  bool operator ==(Object other) =>
      other is ProfileChanges &&
      other.name == name &&
      other.phone == phone &&
      other.birthDate == birthDate;

  @override
  int get hashCode => Object.hash(name, phone, birthDate);

  @override
  String toString() => 'ProfileChanges(name: $name, phone: $phone, birthDate: $birthDate)';
}

/// O que mudou entre o [profile] e os campos da tela: o [name] como foi digitado, o [phone] só com
/// os dígitos e a [birthDate] em `AAAA-MM-DD` (ou como foi digitada, se estiver incompleta). Um
/// campo igual ao do perfil fica de fora, inclusive o nome que só ganhou espaços nas pontas.
ProfileChanges profileChangesOf(
  UserProfile profile, {
  required String name,
  required String phone,
  required String birthDate,
}) {
  final birthDateOfProfile = switch (profile.birthDate) {
    final date? => _isoDate(date),
    null => null,
  };

  return ProfileChanges(
    name: name.trim() == profile.name ? null : name,
    phone: phone == (profile.phone ?? '') ? null : phone,
    birthDate: birthDate == (birthDateOfProfile ?? '') ? null : birthDate,
  );
}

/// A conferência dos dados antes de salvar, com as mesmas regras e mensagens do cadastro (RM11).
/// Só os campos que mudaram são conferidos. Devolve o erro de cada campo recusado, ou um mapa vazio
/// quando as [changes] podem ser enviadas. O [now] decide o "hoje" da data de nascimento.
Map<ProfileField, String> validateProfileChanges(ProfileChanges changes, {DateTime? now}) {
  final ProfileChanges(:name, :phone, :birthDate) = changes;

  return {
    if (name != null && name.trim().isEmpty)
      ProfileField.name: RegistrationMessages.nameMissing
    else if (name != null && !isValidUserName(name))
      ProfileField.name: RegistrationMessages.nameTooLong,
    if (phone != null && phone.trim().isEmpty)
      ProfileField.phone: RegistrationMessages.phoneMissing
    else if (phone != null && !isValidPhone(phone))
      ProfileField.phone: RegistrationMessages.phoneInvalid,
    if (birthDate != null && birthDate.trim().isEmpty)
      ProfileField.birthDate: RegistrationMessages.birthDateMissing
    else if (birthDate != null && !isCalendarDate(birthDate))
      ProfileField.birthDate: RegistrationMessages.birthDateInvalid
    else if (birthDate != null && !isValidBirthDate(birthDate, now: now))
      ProfileField.birthDate: RegistrationMessages.birthDateNotInPast,
  };
}

/// A data sem hora no formato da API, `AAAA-MM-DD`.
String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
