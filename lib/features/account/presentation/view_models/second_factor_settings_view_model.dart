import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/confirmation_password.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_profile.dart';
import 'package:reportaai_cm/features/profile/profile_providers.dart';

/// Estado da tela "Verificação em duas etapas": a escolha do interruptor, o envio em andamento, o
/// erro da senha e o aviso geral.
final NotifierProvider<SecondFactorSettingsViewModel, SecondFactorSettingsState>
secondFactorSettingsViewModelProvider = NotifierProvider.autoDispose(
  SecondFactorSettingsViewModel.new,
);

@immutable
final class SecondFactorSettingsState {
  const new({this.selected, this.isSubmitting = false, this.passwordError, this.message});

  /// Para onde o interruptor foi: ligado para ativar, desligado para desativar. `null` enquanto o
  /// Client não mexeu nele, e o interruptor mostra o estado da conta.
  final bool? selected;

  final bool isSubmitting;

  /// O erro embaixo da senha atual, da conferência antes de enviar ou da senha incorreta (RM15).
  final String? passwordError;

  /// O aviso geral, acima do botão, como sem conexão ou o e-mail ainda não confirmado.
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is SecondFactorSettingsState &&
      other.selected == selected &&
      other.isSubmitting == isSubmitting &&
      other.passwordError == passwordError &&
      other.message == message;

  @override
  int get hashCode => Object.hash(selected, isSubmitting, passwordError, message);

  @override
  String toString() =>
      'SecondFactorSettingsState(selected: $selected, isSubmitting: $isSubmitting, '
      'passwordError: $passwordError, message: $message)';
}

/// Como terminou um envio que chegou à API.
enum SecondFactorSettingsOutcome {
  /// A verificação mudou, e o perfil novo foi para o `AuthController`.
  changed,

  /// A senha atual estava errada: a tela apaga o campo (RM15).
  incorrectPassword,
}

/// Liga e desliga a verificação em duas etapas (`PATCH /api/users/me/mfa`), confirmada com a senha
/// atual (RN24). O perfil que a API devolve vai para o `AuthController`.
final class SecondFactorSettingsViewModel extends Notifier<SecondFactorSettingsState> {
  static const enabledMessage = 'Verificação em duas etapas ativada.';
  static const disabledMessage = 'Verificação em duas etapas desativada.';

  @override
  SecondFactorSettingsState build() => const SecondFactorSettingsState();

  /// O Client mexeu no interruptor. Com o estado da conta de volta, a confirmação sai da tela.
  void select({required bool enabled}) {
    if (state.isSubmitting) return;

    state = SecondFactorSettingsState(selected: enabled == _profile?.mfaEnabled ? null : enabled);
  }

  /// Confirma a mudança escolhida no interruptor com a [password] atual. Devolve o
  /// [SecondFactorSettingsOutcome] quando a API respondeu à senha, ou `null` sem mudança escolhida,
  /// com a senha vazia, durante outro envio e nos outros erros, que ficam no aviso geral.
  Future<SecondFactorSettingsOutcome?> submit(String password) async {
    final enabled = state.selected;
    if (enabled == null || state.isSubmitting || _profile == null) return null;

    if (password.isEmpty) {
      state = SecondFactorSettingsState(
        selected: enabled,
        passwordError: ConfirmationPasswordMessages.missing,
      );
      return null;
    }

    state = SecondFactorSettingsState(selected: enabled, isSubmitting: true);
    // Lido antes da chamada: o perfil novo vai para o resto do app mesmo que a tela feche no meio.
    final auth = ref.read(authControllerProvider.notifier);

    final UserProfile profile;
    try {
      profile = await ref
          .read(profileRepositoryProvider)
          .setMfa(enabled: enabled, password: password);
    } on Object catch (error) {
      final incorrect = isIncorrectPassword(error);
      if (ref.mounted) {
        state = incorrect
            ? SecondFactorSettingsState(
                selected: enabled,
                passwordError: ConfirmationPasswordMessages.incorrect,
              )
            : SecondFactorSettingsState(selected: enabled, message: ApiException.messageOf(error));
      }
      return incorrect ? SecondFactorSettingsOutcome.incorrectPassword : null;
    }

    auth.replaceProfile(profile);
    if (ref.mounted) state = const SecondFactorSettingsState();
    return SecondFactorSettingsOutcome.changed;
  }

  /// O usuário editou a senha: o erro dela sai da tela.
  void passwordChanged() {
    if (state.passwordError == null) return;

    state = SecondFactorSettingsState(selected: state.selected, message: state.message);
  }

  UserProfile? get _profile => switch (ref.read(authControllerProvider)) {
    AuthAuthenticated(:final profile) => profile,
    _ => null,
  };
}
