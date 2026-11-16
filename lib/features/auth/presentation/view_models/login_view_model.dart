import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/domain/models/sign_in_result.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';

/// Estado da tela de login: o envio em andamento e o aviso do último login que não entrou.
final NotifierProvider<LoginViewModel, LoginState> loginViewModelProvider =
    NotifierProvider.autoDispose(LoginViewModel.new);

@immutable
final class LoginState {
  const new({this.isSubmitting = false, this.message});

  final bool isSubmitting;

  /// O aviso do último login que não entrou, como "E-mail ou senha incorretos.".
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is LoginState && other.isSubmitting == isSubmitting && other.message == message;

  @override
  int get hashCode => Object.hash(isSubmitting, message);

  @override
  String toString() => 'LoginState(isSubmitting: $isSubmitting, message: $message)';
}

/// Envia o login pelo `AuthController`. Quem leva à tela inicial é o redirect das rotas, a partir
/// do estado de login: o ViewModel só guarda o carregando e o aviso.
final class LoginViewModel extends Notifier<LoginState> {
  static const wrongCredentialsMessage = 'E-mail ou senha incorretos.';

  @override
  LoginState build() => const LoginState();

  /// Entra com o [email] e a [password]. Um segundo envio, enquanto o primeiro não termina, é
  /// ignorado.
  Future<void> submit({required String email, required String password}) async {
    if (state.isSubmitting) return;
    state = const LoginState(isSubmitting: true);

    String? message;
    try {
      final result = await ref
          .read(authControllerProvider.notifier)
          .signIn(email: email, password: password);
      message = _messageFor(result);
    } on Object catch (error) {
      message = ApiException.messageOf(error);
    }

    // Com o login feito, o redirect troca de tela, e o provider pode já ter sido descartado.
    if (ref.mounted) state = LoginState(message: message);
  }
}

/// A mensagem de cada resultado do login, ou `null` quando ele entrou (RM02 a RM04).
String? _messageFor(SignInResult result) => switch (result) {
  SignInSuccess() => null,
  // A mesma para a senha errada e para a conta inexistente, inativa ou excluída (RM02).
  SignInWrongCredentials() => LoginViewModel.wrongCredentialsMessage,
  SignInFieldError(:final errors) => errors.values.join(' '),
  SignInLocked(:final message) => message,
  SignInRateLimited(:final retryAfter) =>
    'Muitas tentativas. Tente de novo em ${retryAfter.inSeconds} s.',
};
