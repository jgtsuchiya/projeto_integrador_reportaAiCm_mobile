import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/widgets/sign_out_button.dart';
import 'package:reportaai_cm/features/home/presentation/view_models/home_view_model.dart';
import 'package:reportaai_cm/features/home/presentation/widgets/profile_card.dart';

/// Tela inicial (`/inicio`), a primeira com a sessão aberta: a saudação, os dados do usuário e o
/// "Sair". O redirect só abre esta tela com o Client dentro.
///
/// Puxar para atualizar busca o perfil de novo. Se a atualização falhar, os dados já mostrados
/// continuam na tela, com o aviso do erro em cima deles.
class HomeView extends ConsumerStatefulWidget {
  const new({super.key});

  /// A ação do leitor de tela que faz o mesmo que puxar para atualizar, gesto que o TalkBack e o
  /// VoiceOver não fazem. Fica na saudação.
  static const refreshAction = CustomSemanticsAction(label: 'Atualizar os dados');

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  final _refreshIndicator = GlobalKey<RefreshIndicatorState>();

  Future<void> _refresh() => ref.read(homeViewModelProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    // Depois do "Sair", a tela ainda aparece durante a troca para o login, já sem o perfil.
    final profile = switch (ref.watch(authControllerProvider)) {
      AuthAuthenticated(:final profile) => profile,
      _ => null,
    };
    final refreshError = ref.watch(homeViewModelProvider).refreshError;

    return Scaffold(
      appBar: AppBar(title: const Text('ReportaAi Cm'), actions: const [SignOutButton()]),
      body: SafeArea(
        child: profile == null
            ? const SizedBox.shrink()
            : RefreshIndicator(
                key: _refreshIndicator,
                onRefresh: _refresh,
                child: SingleChildScrollView(
                  // O puxar para atualizar funciona também quando tudo cabe na tela, sem rolar.
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: ScrollableCenter.maxContentWidth),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (refreshError != null) ...[
                              _RefreshErrorNotice(message: refreshError),
                              const SizedBox(height: 16),
                            ],
                            _Greeting(
                              firstName: profile.firstName,
                              onRefresh: () => unawaited(_refreshIndicator.currentState?.show()),
                            ),
                            const SizedBox(height: 24),
                            ProfileCard(profile: profile),
                            const SizedBox(height: 16),
                            const _ReportsSoonCard(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const new({required this.firstName, required this.onRefresh});

  final String firstName;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      customSemanticsActions: {HomeView.refreshAction: onRefresh},
      child: Text('Olá, $firstName', style: Theme.of(context).textTheme.headlineMedium),
    );
  }
}

/// O aviso da atualização que falhou, em cima dos dados que continuam na tela.
class _RefreshErrorNotice extends StatelessWidget {
  const new({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onErrorContainer;

    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.errorContainer,
      // O leitor de tela anuncia o aviso assim que ele aparece. Fica dentro do cartão, que é o nó
      // que o leitor de tela lê.
      child: Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Os dados não foram atualizados',
                      style: theme.textTheme.titleSmall?.copyWith(color: color),
                    ),
                    const SizedBox(height: 4),
                    Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: color)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// O aviso de que os reportes chegam em breve, sem ação nesta versão.
class _ReportsSoonCard extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.add_road, size: 32, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reportes em breve', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Logo você vai poder reportar os buracos da cidade e acompanhar cada reporte '
                    'por aqui.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
