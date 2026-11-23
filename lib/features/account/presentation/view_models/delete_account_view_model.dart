import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/confirmation_password.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';

/// Estado da tela "Excluir conta": o envio em andamento, o erro da senha e o aviso geral.
final NotifierProvider<DeleteAccountViewModel, DeleteAccountState> deleteAccountViewModelProvider =
    NotifierProvider.autoDispose(DeleteAccountViewModel.new);

@immutable
final class DeleteAccountState {
  const new({this.isSubmitting = false, this.passwordError, this.message});

  final bool isSubmitting;

  /// O erro embaixo da senha atual: a senha incorreta (RM15).
  final String? passwordError;

  /// O aviso geral, acima do botão, como sem conexão.
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is DeleteAccountState &&
      other.isSubmitting == isSubmitting &&
      other.passwordError == passwordError &&
      other.message == message;

  @override
  int get hashCode => Object.hash(isSubmitting, passwordError, message);

  @override
  String toString() =>
      'DeleteAccountState(isSubmitting: $isSubmitting, passwordError: $passwordError, '
      'message: $message)';
}

/// Exclui a conta pelo `AuthController`, que apaga a sessão do aparelho e volta ao login com o
/// aviso da exclusão (RM17). Quem leva ao login é o redirect das rotas.
final class DeleteAccountViewModel extends Notifier<DeleteAccountState> {
  @override
  DeleteAccountState build() => const DeleteAccountState();

  /// Exclui a conta com a [password] atual. Devolve `false` com a senha incorreta, para a tela
  /// apagar o campo, e `true` nos outros casos. Ignorado com a senha vazia e durante outro envio.
  Future<bool> submit(String password) async {
    if (password.isEmpty || state.isSubmitting) return true;

    state = const DeleteAccountState(isSubmitting: true);

    DeleteAccountState next;
    var isPasswordCorrect = true;
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount(password: password);
      next = const DeleteAccountState();
    } on Object catch (error) {
      if (isIncorrectPassword(error)) {
        next = const DeleteAccountState(passwordError: ConfirmationPasswordMessages.incorrect);
        isPasswordCorrect = false;
      } else {
        next = DeleteAccountState(message: ApiException.messageOf(error));
      }
    }

    // A tela fecha quando a exclusão leva ao login.
    if (ref.mounted) state = next;
    return isPasswordCorrect;
  }

  /// O usuário editou a senha: o erro dela sai da tela.
  void passwordChanged() {
    if (state.passwordError == null) return;

    state = DeleteAccountState(message: state.message);
  }
}
