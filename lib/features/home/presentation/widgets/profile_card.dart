import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/utils/cpf_formatters.dart';
import 'package:reportaai_cm/core/utils/date_formatters.dart';
import 'package:reportaai_cm/core/utils/phone_formatters.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_profile.dart';

/// O cartão "Seus dados" da tela inicial, com o perfil do `GET /api/users/me` formatado. O CPF
/// aparece mascarado (RM09), e o e-mail ainda não confirmado ganha um selo, só informativo.
class ProfileCard extends StatelessWidget {
  const new({required this.profile, super.key});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final UserProfile(:cpf, :phone, :birthDate) = profile;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text('Seus dados', style: theme.textTheme.titleLarge)),
            const SizedBox(height: 16),
            _ProfileField(label: 'Nome', value: profile.name),
            _ProfileField(
              label: 'E-mail',
              value: profile.email,
              tag: profile.emailVerifiedAt == null ? const _UnverifiedEmailTag() : null,
            ),
            // Os campos do Client. Sem eles (um perfil fora do esperado), a linha não aparece.
            if (cpf != null) _ProfileField(label: 'CPF', value: maskCpf(cpf)),
            if (phone != null) _ProfileField(label: 'Telefone', value: formatPhone(phone)),
            if (birthDate != null)
              // Uma data sem hora: sem o `toLocal()`, para não mudar o dia.
              _ProfileField(label: 'Data de nascimento', value: formatDate(birthDate)),
            Text(
              'No ReportaAi desde ${formatMonthYear(profile.createdAt.toLocal())}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Um dado do perfil: o rótulo em cima e o valor embaixo, com o [tag] opcional depois do valor.
class _ProfileField extends StatelessWidget {
  const new({required this.label, required this.value, this.tag});

  final String label;
  final String value;
  final Widget? tag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      // O leitor de tela lê o rótulo, o valor e o selo juntos: "E-mail, maria@..., E-mail não
      // confirmado".
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(value, style: theme.textTheme.bodyLarge),
            if (tag case final tag?) ...[const SizedBox(height: 8), tag],
          ],
        ),
      ),
    );
  }
}

/// O selo do e-mail ainda não confirmado (`emailVerifiedAt` nulo). Só informa: o reenvio da
/// verificação fica para o próximo épico.
class _UnverifiedEmailTag extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 16, color: colors.onTertiaryContainer),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'E-mail não confirmado',
                style: theme.textTheme.labelMedium?.copyWith(color: colors.onTertiaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
