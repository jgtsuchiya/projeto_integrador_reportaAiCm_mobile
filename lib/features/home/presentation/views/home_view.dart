import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/widgets/sign_out_button.dart';

/// Tela inicial (`/inicio`), a primeira com a sessão aberta: quem entrou e o "Sair". O redirect só
/// abre esta tela com o Client dentro.
///
/// Provisória: a saudação, o cartão com os dados do usuário e o puxar para atualizar entram com a
/// tela inicial completa.
class HomeView extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Depois do "Sair", a tela ainda aparece durante a troca para o login, já sem o perfil.
    final profile = switch (ref.watch(authControllerProvider)) {
      AuthAuthenticated(:final profile) => profile,
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('ReportaAi Cm'), actions: const [SignOutButton()]),
      body: SafeArea(
        child: ScrollableCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_road, size: 64, color: theme.colorScheme.primary),
              if (profile != null) ...[
                const SizedBox(height: 16),
                Text('Você entrou como', style: theme.textTheme.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  profile.name,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(profile.email, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              Text(
                'Os seus dados e os reportes de buracos chegam nas próximas versões.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
