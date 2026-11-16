import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';

/// O "Sair": encerra a sessão pelo `AuthController`, e o redirect leva ao login. Sem conexão, o
/// usuário continua logado e vê o erro num `SnackBar` (RM10). Enquanto a saída não termina, o
/// botão fica desativado, para não sair duas vezes.
class SignOutButton extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends ConsumerState<SignOutButton> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);

    try {
      await ref.read(authControllerProvider.notifier).signOut();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiException.messageOf(error))));
      }
    }

    if (mounted) setState(() => _isSigningOut = false);
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: _isSigningOut ? null : _signOut, child: const Text('Sair'));
  }
}
