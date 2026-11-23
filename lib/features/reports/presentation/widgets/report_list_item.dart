import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/utils/date_formatters.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_draft.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/report_photo_view.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/report_status_label.dart';

/// Um reporte numa lista: a miniatura (buscada só quando o item aparece), o status em texto e cor
/// (RM26), "3 de 10 confirmações" com a barra no reporte em validação, a descrição numa linha e a
/// data. O toque abre o detalhe.
class ReportListItem extends StatelessWidget {
  const new({required this.report, required this.onTap, super.key});

  final Report report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = report.description;
    final secondary = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    // O leitor de tela lê o reporte inteiro como um botão só.
    return MergeSemantics(
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox.square(
                    dimension: 72,
                    child: ReportPhotoView(
                      reportId: report.id,
                      photo: report.photo,
                      size: ReportPhotoSize.thumbnail,
                      semanticLabel: 'Foto do reporte',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: ReportStatusLabel(status: report.status),
                      ),
                      if (report.status == ReportStatus.pending) ...[
                        const SizedBox(height: 8),
                        ReportConfirmationProgress(votes: report.votes),
                      ],
                      if (description != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text('Aberto em ${formatDate(report.createdAt.toLocal())}', style: secondary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
