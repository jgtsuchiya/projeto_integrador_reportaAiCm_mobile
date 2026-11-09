import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/core/widgets/error_view.dart';
import 'package:reportaai_cm/core/widgets/loading_indicator.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/widgets/sign_out_button.dart';

/// Tela de abertura (`/abertura`): o carregando enquanto o app confere a sessão guardada e, quando
/// o perfil não carrega (ex.: sem rede), o erro com o "Tentar de novo" e o "Sair" (RM06). Quem
/// sai daqui para o login ou para a tela inicial é o redirect das rotas.
class SplashView extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: switch (auth) {
          AuthLoadFailed(:final error) => ErrorView(
            title: 'Não foi possível abrir a sua conta',
            message: ApiException.messageOf(error),
            onRetry: () => unawaited(ref.read(authControllerProvider.notifier).retry()),
            secondaryAction: const SignOutButton(),
          ),
          // Também no instante entre a conferência e a troca de tela.
          _ => const LoadingIndicator(),
        },
      ),
    );
  }
}
