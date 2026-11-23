import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/routes.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/widgets/email_verification_notice.dart';
import 'package:reportaai_cm/features/auth/presentation/widgets/sign_out_button.dart';
import 'package:reportaai_cm/features/home/presentation/view_models/home_view_model.dart';
import 'package:reportaai_cm/features/profile/presentation/widgets/profile_card.dart';

/// Tela inicial (`/inicio`), a primeira com a sessão aberta: a saudação, o aviso do e-mail ainda
/// não confirmado (RM14), as entradas dos reportes, os dados do usuário, a "Minha conta" e o
/// "Sair". O redirect só abre esta tela com o Client dentro.
///
/// O "Novo reporte" só aparece com o e-mail confirmado: sem ele, o aviso do e-mail fica no lugar
/// (RM20).
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
      appBar: AppBar(
        title: const Text('ReportaAi Cm'),
        actions: [
          // Por cima da tela inicial: o "voltar" volta para ela.
          IconButton(
            onPressed: () => unawaited(context.push(AppRoutes.account)),
            tooltip: 'Minha conta',
            icon: const Icon(Icons.account_circle_outlined),
          ),
          const SignOutButton(),
        ],
      ),
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
                            // Só com o e-mail ainda não confirmado (RM14). Ele toma o lugar do
                            // "Novo reporte" (RM20).
                            if (profile.emailVerifiedAt == null) ...[
                              const EmailVerificationNotice(),
                              const SizedBox(height: 16),
                            ] else ...[
                              FilledButton.icon(
                                onPressed: () => unawaited(context.push(AppRoutes.newReport)),
                                icon: const Icon(Icons.add_a_photo_outlined),
                                label: const Text('Novo reporte'),
                              ),
                              const SizedBox(height: 16),
                            ],
                            const _ReportsCard(),
                            const SizedBox(height: 16),
                            ProfileCard(profile: profile),
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

/// As entradas dos reportes: "Meus reportes" e "Reportes perto de você", que chega com a validação
/// dos reportes.
class _ReportsCard extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.list_alt_outlined),
            title: const Text('Meus reportes'),
            subtitle: const Text('Acompanhe os buracos que você reportou'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => unawaited(context.push(AppRoutes.reports)),
          ),
          const Divider(height: 1),
          const ListTile(
            enabled: false,
            leading: Icon(Icons.near_me_outlined),
            title: Text('Reportes perto de você'),
            subtitle: Text('Em breve: confirme os buracos que outros cidadãos reportaram'),
          ),
        ],
      ),
    );
  }
}
