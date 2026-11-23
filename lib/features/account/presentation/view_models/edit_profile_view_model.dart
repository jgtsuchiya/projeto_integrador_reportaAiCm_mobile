import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/core/utils/date_formatters.dart';
import 'package:reportaai_cm/core/utils/masked_input_formatter.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/profile/domain/models/profile_changes.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_profile.dart';
import 'package:reportaai_cm/features/profile/profile_providers.dart';

/// Estado da tela "Editar dados": o envio em andamento, o erro de cada campo e o aviso geral.
final NotifierProvider<EditProfileViewModel, EditProfileState> editProfileViewModelProvider =
    NotifierProvider.autoDispose(EditProfileViewModel.new);

@immutable
final class EditProfileState {
  const new({this.isSubmitting = false, this.fieldErrors = const {}, this.message});

  final bool isSubmitting;

  /// O erro de cada campo, da conferência antes de enviar ou do 400 da API.
  final Map<ProfileField, String> fieldErrors;

  /// O aviso geral, acima do "Salvar", como sem conexão.
  final String? message;

  String? errorFor(ProfileField field) => fieldErrors[field];

  @override
  bool operator ==(Object other) =>
      other is EditProfileState &&
      other.isSubmitting == isSubmitting &&
      mapEquals(other.fieldErrors, fieldErrors) &&
      other.message == message;

  @override
  int get hashCode => Object.hash(
    isSubmitting,
    Object.hashAllUnordered([
      for (final MapEntry(:key, :value) in fieldErrors.entries) Object.hash(key, value),
    ]),
    message,
  );

  @override
  String toString() =>
      'EditProfileState(isSubmitting: $isSubmitting, fieldErrors: $fieldErrors, '
      'message: $message)';
}

/// O que mudou entre o [profile] e os campos da tela, como estão nela, com a máscara: o telefone
/// vai só com os dígitos, e a data em `AAAA-MM-DD` (ou como foi digitada, se estiver incompleta).
ProfileChanges profileChangesOfFields(
  UserProfile profile, {
  required String name,
  required String phone,
  required String birthDate,
}) => profileChangesOf(
  profile,
  name: name,
  phone: digitsOnly(phone),
  birthDate: maskedDateToIso(birthDate) ?? birthDate.trim(),
);

/// Salva o nome, o telefone e a data de nascimento do Client (`PATCH /api/users/me`), só os campos
/// que mudaram. O perfil que a API devolve vai para o `AuthController`, e a tela inicial e a
/// "Minha conta" mostram os dados novos sem buscar o perfil de novo.
final class EditProfileViewModel extends Notifier<EditProfileState> {
  static const savedMessage = 'Dados salvos.';

  @override
  EditProfileState build() => const EditProfileState();

  /// Confere e salva os campos como estão na tela, com a máscara. Devolve `true` quando salvou.
  /// Sem mudança, com um campo recusado, durante outro envio ou sem o Client dentro, não chama a
  /// API e devolve `false`.
  Future<bool> submit({
    required String name,
    required String phone,
    required String birthDate,
  }) async {
    final profile = switch (ref.read(authControllerProvider)) {
      AuthAuthenticated(:final profile) => profile,
      _ => null,
    };
    if (profile == null || state.isSubmitting) return false;

    final changes = profileChangesOfFields(profile, name: name, phone: phone, birthDate: birthDate);
    if (changes.isEmpty) return false;

    final fieldErrors = validateProfileChanges(changes);
    if (fieldErrors.isNotEmpty) {
      state = EditProfileState(fieldErrors: fieldErrors);
      return false;
    }

    state = const EditProfileState(isSubmitting: true);
    // Lido antes da chamada: o perfil salvo vai para o resto do app mesmo que a tela feche no meio.
    final auth = ref.read(authControllerProvider.notifier);

    final UserProfile updated;
    try {
      updated = await ref.read(profileRepositoryProvider).updateMe(changes);
    } on ValidationException catch (error) {
      if (ref.mounted) state = _fromValidation(error);
      return false;
    } on Object catch (error) {
      if (ref.mounted) state = EditProfileState(message: ApiException.messageOf(error));
      return false;
    }

    auth.replaceProfile(updated);
    if (ref.mounted) state = const EditProfileState();
    return true;
  }

  /// O usuário editou o [field]: o erro dele sai da tela, e o dos outros campos continua.
  void fieldChanged(ProfileField field) {
    if (state.errorFor(field) == null) return;

    state = EditProfileState(
      fieldErrors: Map.unmodifiable({...state.fieldErrors}..remove(field)),
      message: state.message,
    );
  }

  /// O 400 da API: o erro de cada campo que o app conhece, embaixo dele. Sem nenhum, a mensagem
  /// geral.
  EditProfileState _fromValidation(ValidationException error) {
    final fieldErrors = {
      for (final FieldError(:field, :message) in error.fieldErrors)
        ?ProfileField.fromApiName(field): message,
    };

    return fieldErrors.isEmpty
        ? EditProfileState(message: error.message)
        : EditProfileState(fieldErrors: fieldErrors);
  }
}
