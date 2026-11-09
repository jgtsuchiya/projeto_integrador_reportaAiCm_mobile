import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';

/// Estado da tela inicial: o aviso do último "puxar para atualizar" que falhou. O perfil fica no
/// `AuthController`, a fonte da verdade do login.
final NotifierProvider<HomeViewModel, HomeState> homeViewModelProvider =
    NotifierProvider.autoDispose(HomeViewModel.new);

@immutable
final class HomeState {
  const new({this.refreshError});

  /// A mensagem do último "puxar para atualizar" que falhou, como sem conexão. Os dados que já
  /// estavam na tela continuam nela.
  final String? refreshError;

  @override
  bool operator ==(Object other) => other is HomeState && other.refreshError == refreshError;

  @override
  int get hashCode => refreshError.hashCode;

  @override
  String toString() => 'HomeState(refreshError: $refreshError)';
}

/// Atualiza o perfil pelo `AuthController`, que guarda o perfil novo para a tela. O ViewModel
/// guarda só o aviso da atualização que falhou.
final class HomeViewModel extends Notifier<HomeState> {
  @override
  HomeState build() => const HomeState();

  /// Busca o perfil de novo. O aviso anterior sai assim que a atualização começa, e um novo
  /// aparece se ela também falhar. Quando a sessão acabou, o redirect leva ao login, sem aviso
  /// aqui.
  Future<void> refresh() async {
    state = const HomeState();

    try {
      await ref.read(authControllerProvider.notifier).refreshProfile();
    } on Object catch (error) {
      // A tela pode ter fechado enquanto a atualização esperava a API.
      if (ref.mounted) state = HomeState(refreshError: ApiException.messageOf(error));
    }
  }
}
