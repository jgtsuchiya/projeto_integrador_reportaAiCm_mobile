import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/utils/date_formatters.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_draft.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/report_location_card.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/report_photo_view.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/report_status_label.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/report_vote_bar.dart';

/// Um reporte dos "Reportes perto de você" (RM28): a miniatura (buscada só quando o item aparece),
/// a distância, "3 de 10 confirmações", a descrição numa linha e a data, que abrem o detalhe no
/// toque, e embaixo o voto ([ReportVoteBar]), ou o voto já dado.
class NearbyReportItem extends StatelessWidget {
  const new({required this.report, required this.onTap, super.key});

  final Report report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = report.description;
    final distance = report.distanceMeters;
    final secondary = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // O leitor de tela lê o reporte como um botão só. O voto fica fora: os botões dele são
          // lidos um a um.
          MergeSemantics(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
                          if (distance != null)
                            Text(distanceText(distance), style: theme.textTheme.titleSmall),
                          // O voto pode ter confirmado ou descartado o reporte.
                          if (report.status != ReportStatus.pending) ...[
                            const SizedBox(height: 4),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: ReportStatusLabel(status: report.status),
                            ),
                          ],
                          const SizedBox(height: 8),
                          ReportConfirmationProgress(votes: report.votes),
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
                          Text(
                            'Aberto em ${formatDate(report.createdAt.toLocal())}',
                            style: secondary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (ReportVoteBar.appliesTo(report))
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: ReportVoteBar(report: report, compact: true),
            ),
        ],
      ),
    );
  }
}
