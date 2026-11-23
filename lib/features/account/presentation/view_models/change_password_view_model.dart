import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/confirmation_password.dart';
import 'package:reportaai_cm/features/auth/domain/models/password.dart';
import 'package:reportaai_cm/features/profile/profile_providers.dart';

/// Estado da tela "Trocar senha": o envio em andamento, o erro de cada campo e o aviso geral.
final NotifierProvider<ChangePasswordViewModel, ChangePasswordState>
changePasswordViewModelProvider = NotifierProvider.autoDispose(ChangePasswordViewModel.new);

/// Os campos da troca de senha.
enum ChangePasswordField { currentPassword, newPassword, confirmation }

@immutable
final class ChangePasswordState {
  const new({this.isSubmitting = false, this.fieldErrors = const {}, this.message});

  final bool isSubmitting;

  /// O erro de cada campo, da conferência antes de enviar ou da API.
  final Map<ChangePasswordField, String> fieldErrors;

  /// O aviso geral, acima do botão, como sem conexão.
  final String? message;

  String? errorFor(ChangePasswordField field) => fieldErrors[field];

  @override
  bool operator ==(Object other) =>
      other is ChangePasswordState &&
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
      'ChangePasswordState(isSubmitting: $isSubmitting, fieldErrors: $fieldErrors, '
      'message: $message)';
}

/// Como terminou um envio da troca de senha que chegou à API.
enum ChangePasswordOutcome {
  /// A senha mudou. Este aparelho continua logado, e os outros saem (RN13 e RM16).
  changed,

  /// A senha atual estava errada: a tela apaga o campo (RM15).
  incorrectPassword,
}

/// Troca a senha (`PATCH /api/users/me/password`), com a senha nova pela política da RN08, a
/// mesma do cadastro (RM15 e RM16).
final class ChangePasswordViewModel extends Notifier<ChangePasswordState> {
  static const newPasswordMissingMessage = 'Informe a senha nova.';
  static const confirmationMissingMessage = 'Repita a senha nova.';
  static const confirmationMismatchMessage = 'As senhas não são iguais.';
  static const changedMessage = 'Senha alterada. Os outros aparelhos vão precisar entrar de novo.';

  @override
  ChangePasswordState build() => const ChangePasswordState();

  /// Confere e envia a troca. Devolve o [ChangePasswordOutcome] quando a API respondeu à senha, ou
  /// `null` quando um campo foi recusado antes, durante outro envio e nos outros erros, que ficam
  /// no aviso geral.
  Future<ChangePasswordOutcome?> submit({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  }) async {
    if (state.isSubmitting) return null;

    final fieldErrors = _validate(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmation: confirmation,
    );
    if (fieldErrors.isNotEmpty) {
      state = ChangePasswordState(fieldErrors: fieldErrors);
      return null;
    }

    state = const ChangePasswordState(isSubmitting: true);

    ChangePasswordState next;
    ChangePasswordOutcome? outcome;
    try {
      await ref
          .read(profileRepositoryProvider)
          .changePassword(currentPassword: currentPassword, newPassword: newPassword);
      next = const ChangePasswordState();
      outcome = ChangePasswordOutcome.changed;
    } on Object catch (error) {
      if (isIncorrectPassword(error)) {
        next = const ChangePasswordState(
          fieldErrors: {
            ChangePasswordField.currentPassword: ConfirmationPasswordMessages.incorrect,
          },
        );
        outcome = ChangePasswordOutcome.incorrectPassword;
      } else if (error is ValidationException) {
        next = _fromValidation(error);
      } else {
        next = ChangePasswordState(message: ApiException.messageOf(error));
      }
    }

    if (ref.mounted) state = next;
    return outcome;
  }

  /// O usuário editou o [field]: o erro dele sai da tela, e o dos outros campos continua.
  void fieldChanged(ChangePasswordField field) {
    if (state.errorFor(field) == null) return;

    state = ChangePasswordState(
      fieldErrors: Map.unmodifiable({...state.fieldErrors}..remove(field)),
      message: state.message,
    );
  }

  Map<ChangePasswordField, String> _validate({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  }) => {
    if (currentPassword.isEmpty)
      ChangePasswordField.currentPassword: ConfirmationPasswordMessages.missing,
    if (newPassword.isEmpty)
      ChangePasswordField.newPassword: newPasswordMissingMessage
    else
      ChangePasswordField.newPassword: ?validatePassword(newPassword),
    if (confirmation.isEmpty)
      ChangePasswordField.confirmation: confirmationMissingMessage
    else if (confirmation != newPassword)
      ChangePasswordField.confirmation: confirmationMismatchMessage,
  };

  /// O 400 da API: o erro da senha nova ou da atual, embaixo do campo. Sem nenhum, a mensagem
  /// geral.
  ChangePasswordState _fromValidation(ValidationException error) {
    final fieldErrors = {
      ChangePasswordField.currentPassword: ?error.messageFor('currentPassword'),
      ChangePasswordField.newPassword: ?error.messageFor('newPassword'),
    };

    return fieldErrors.isEmpty
        ? ChangePasswordState(message: error.message)
        : ChangePasswordState(fieldErrors: fieldErrors);
  }
}
