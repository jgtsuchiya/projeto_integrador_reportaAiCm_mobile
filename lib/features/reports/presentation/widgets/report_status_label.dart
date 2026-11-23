import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/utils/date_formatters.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';

/// O nome do status na tela (RM26).
String reportStatusText(ReportStatus status) => switch (status) {
  ReportStatus.pending => 'Em validação',
  ReportStatus.confirmed => 'Confirmado',
  ReportStatus.rejected => 'Descartado',
  ReportStatus.unknown => 'Em acompanhamento',
};

/// "3 de 10 confirmações", ou "1 de 10 confirmação" no singular do número pedido.
String confirmationsText(ReportVotes votes) =>
    '${votes.confirmations} de ${votes.confirmationsRequired} '
    '${votes.confirmationsRequired == 1 ? 'confirmação' : 'confirmações'}';

/// O que o status quer dizer, embaixo dele no detalhe: o progresso fica no
/// [ReportConfirmationProgress].
String? reportStatusDetail(Report report) => switch (report.status) {
  ReportStatus.pending => null,
  ReportStatus.confirmed => switch (report.statusChangedAt) {
    final date? => 'Confirmado por outros cidadãos em ${formatDate(date.toLocal())}',
    null => 'Confirmado por outros cidadãos',
  },
  ReportStatus.rejected => 'Outros cidadãos não encontraram o buraco',
  ReportStatus.unknown => 'A prefeitura está acompanhando o reporte',
};

/// O status do reporte em texto, com o ícone e a cor (RM26): a cor ajuda, mas o texto diz tudo,
/// sozinho.
class ReportStatusLabel extends StatelessWidget {
  const new({required this.status, super.key});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch (status) {
      ReportStatus.pending => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
        Icons.hourglass_top,
      ),
      ReportStatus.confirmed => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
        Icons.check_circle_outline,
      ),
      ReportStatus.rejected => (
        colors.errorContainer,
        colors.onErrorContainer,
        Icons.cancel_outlined,
      ),
      ReportStatus.unknown => (
        colors.surfaceContainerHighest,
        colors.onSurface,
        Icons.info_outline,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 4),
            // Com a fonte grande, o texto quebra em vez de ser cortado.
            Flexible(
              child: Text(
                reportStatusText(status),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "3 de 10 confirmações", com a barra do progresso, no reporte em validação.
class ReportConfirmationProgress extends StatelessWidget {
  const new({required this.votes, super.key});

  final ReportVotes votes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = confirmationsText(votes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        // O texto já diz o progresso: a barra não repete para o leitor de tela.
        ExcludeSemantics(
          child: LinearProgressIndicator(
            value: votes.confirmationProgress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }
}
