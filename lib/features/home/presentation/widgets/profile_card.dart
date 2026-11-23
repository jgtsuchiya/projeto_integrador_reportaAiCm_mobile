import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/utils/cpf_formatters.dart';
import 'package:reportaai_cm/core/utils/date_formatters.dart';
import 'package:reportaai_cm/core/utils/phone_formatters.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_profile.dart';

/// O cartão "Seus dados" da tela inicial, com o perfil do `GET /api/users/me` formatado. O CPF
/// aparece mascarado (RM09). O e-mail ainda não confirmado fica com o `EmailVerificationNotice`,
/// fora do cartão.
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
            _ProfileField(label: 'E-mail', value: profile.email),
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

/// Um dado do perfil: o rótulo em cima e o valor embaixo.
class _ProfileField extends StatelessWidget {
  const new({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      // O leitor de tela lê o rótulo e o valor juntos: "Telefone, (44) 99999-8888".
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
          ],
        ),
      ),
    );
  }
}
