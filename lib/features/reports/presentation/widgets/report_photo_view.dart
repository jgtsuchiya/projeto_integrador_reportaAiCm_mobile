import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_draft.dart';
import 'package:reportaai_cm/features/reports/reports_providers.dart';

/// A foto ou a miniatura de um reporte, pelo cache das fotos (`reportPhotoProvider`). A imagem só
/// é buscada quando o widget aparece: numa lista com o `ListView.builder`, só a dos itens à vista.
///
/// Enquanto carrega, um espaço com o indicador. Se falhar, um ícone no lugar, sem derrubar a
/// tela, e o toque busca de novo.
class ReportPhotoView extends ConsumerWidget {
  const new({
    required this.reportId,
    required this.photo,
    required this.size,
    required this.semanticLabel,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String reportId;
  final ReportPhotoInfo photo;
  final ReportPhotoSize size;

  /// O que o leitor de tela lê, como "Foto do buraco".
  final String semanticLabel;

  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = reportPhotoKey(reportId, photo, size);
    final colors = Theme.of(context).colorScheme;

    return ref
        .watch(reportPhotoProvider(key))
        .when(
          // Durante a atualização, a imagem que já estava na tela continua.
          skipLoadingOnRefresh: true,
          data: (bytes) =>
              Image.memory(bytes, fit: fit, gaplessPlayback: true, semanticLabel: semanticLabel),
          loading: () => ColoredBox(
            color: colors.surfaceContainerHighest,
            child: const Center(
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  semanticsLabel: 'Carregando a foto',
                ),
              ),
            ),
          ),
          error: (error, stackTrace) => Semantics(
            button: true,
            label: 'A foto não carregou. Toque para tentar de novo.',
            child: InkWell(
              onTap: () => ref.invalidate(reportPhotoProvider(key)),
              child: ColoredBox(
                color: colors.surfaceContainerHighest,
                child: Center(
                  child: ExcludeSemantics(
                    child: Icon(Icons.broken_image_outlined, color: colors.onSurfaceVariant),
                  ),
                ),
              ),
            ),
          ),
        );
  }
}
