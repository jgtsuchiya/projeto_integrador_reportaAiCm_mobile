import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/routes.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/widgets/sign_out_button.dart';
import 'package:reportaai_cm/features/profile/presentation/widgets/profile_card.dart';

/// "Minha conta" (`/conta`), aberta pela tela inicial: os dados do Client, com o CPF mascarado
/// (RM09), as entradas das telas da conta e o "Sair". As telas da conta abrem por cima desta, e o
/// "voltar" volta para ela.
class AccountView extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Depois da exclusão ou do "Sair", a tela ainda aparece durante a troca para o login.
    final profile = switch (ref.watch(authControllerProvider)) {
      AuthAuthenticated(:final profile) => profile,
      _ => null,
    };

    void open(String route) => unawaited(context.push(route));

    return Scaffold(
      appBar: AppBar(title: const Text('Minha conta')),
      body: SafeArea(
        child: profile == null
            ? const SizedBox.shrink()
            : SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: ScrollableCenter.maxContentWidth),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ProfileCard(profile: profile),
                          const SizedBox(height: 16),
                          Card(
                            margin: EdgeInsets.zero,
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                _AccountEntry(
                                  icon: Icons.edit_outlined,
                                  title: 'Editar dados',
                                  subtitle: 'Nome, telefone e data de nascimento',
                                  onTap: () => open(AppRoutes.accountDetails),
                                ),
                                _AccountEntry(
                                  icon: Icons.password_outlined,
                                  title: 'Trocar senha',
                                  onTap: () => open(AppRoutes.accountPassword),
                                ),
                                _AccountEntry(
                                  icon: Icons.devices_outlined,
                                  title: 'Sessões abertas',
                                  subtitle: 'Os aparelhos em que a conta está aberta',
                                  onTap: () => open(AppRoutes.accountSessions),
                                ),
                                _AccountEntry(
                                  icon: Icons.verified_user_outlined,
                                  title: 'Verificação em duas etapas',
                                  subtitle: profile.mfaEnabled ? 'Ativada' : 'Desativada',
                                  onTap: () => open(AppRoutes.accountSecondFactor),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            margin: EdgeInsets.zero,
                            clipBehavior: Clip.antiAlias,
                            child: _AccountEntry(
                              icon: Icons.delete_outline,
                              title: 'Excluir conta',
                              isDestructive: true,
                              onTap: () => open(AppRoutes.accountDeletion),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Center(child: SignOutButton()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Uma entrada da lista, que abre uma tela da conta.
class _AccountEntry extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  /// A exclusão da conta, na cor de erro.
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Theme.of(context).colorScheme.error : null;
    final subtitle = this.subtitle;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
