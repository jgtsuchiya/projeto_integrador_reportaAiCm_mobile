import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/theme/success_colors.dart';
import 'package:reportaai_cm/features/auth/domain/models/password.dart';

/// A política de senha (RN08) embaixo do campo, com cada item marcado quando a senha digitada já
/// o cumpre. Serve ao cadastro e à troca de senha, que usam a mesma política.
///
/// Acompanha o [password] (o controller do campo) a cada letra digitada. O leitor de tela lê cada
/// item com o estado dele, sem anunciar a cada letra.
class PasswordRules extends StatelessWidget {
  const new({required this.password, super.key});

  final ValueListenable<TextEditingValue> password;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder(
      valueListenable: password,
      builder: (context, value, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A senha precisa ter:',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          for (final rule in PasswordRule.values)
            _PasswordRuleItem(label: rule.label, isMet: rule.isMetBy(value.text)),
        ],
      ),
    );
  }
}

class _PasswordRuleItem extends StatelessWidget {
  const new({required this.label, required this.isMet});

  final String label;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // O item cumprido fica no verde: o ícone e o texto dizem o estado, e a cor ajuda.
    final color = isMet ? SuccessColors.of(context).success : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      label: '$label: ${isMet ? 'cumprido' : 'ainda não cumprido'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isMet ? Icons.check_circle : Icons.circle_outlined, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}
