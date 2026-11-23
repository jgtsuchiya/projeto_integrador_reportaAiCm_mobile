import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/theme/app_theme.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_limits.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_location.dart';

/// A precisão como a tela mostra: "Precisão de 8 m", arredondada para cima, como a API guarda.
String accuracyText(double accuracyMeters) => 'Precisão de ${accuracyMeters.ceil()} m';

/// A distância até o reporte, como as telas mostram: "A 120 m de você".
String distanceText(int distanceMeters) =>
    distanceMeters < 1 ? 'A menos de 1 m de você' : 'A $distanceMeters m de você';

/// Para que a tela lê a localização: o texto do cartão diz o porquê de cada uma.
enum LocationPurpose {
  /// Mostrar onde fica o buraco, na abertura do reporte (RM21).
  report,

  /// Conferir se o cidadão está perto do buraco, no voto (RM29).
  vote,

  /// Buscar os reportes em validação perto do cidadão (RM28).
  nearby,
}

/// A localização do aparelho na abertura do reporte (RM21), no voto (RM29) e nos "Reportes perto de
/// você" (RM28): a precisão, ou o que impede seguir, com a ação que resolve (o "Atualizar
/// localização", o pedido da permissão, as configurações). As regras são as mesmas nas três: o
/// [purpose] só troca o porquê, no texto.
class ReportLocationCard extends StatelessWidget {
  const new({
    required this.reading,
    required this.onRefresh,
    required this.onRequestPermission,
    required this.onOpenAppSettings,
    required this.onOpenLocationSettings,
    this.purpose = LocationPurpose.report,
    super.key,
  });

  final LocationReading reading;
  final LocationPurpose purpose;
  final VoidCallback onRefresh;
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenAppSettings;
  final VoidCallback onOpenLocationSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accuracy = switch (reading.position) {
      final position? => accuracyText(position.accuracyMeters),
      null => null,
    };
    const limit = ReportLimits.maxAccuracyMeters;
    final (goal, permissionReason, deniedReason, serviceGoal) = switch (purpose) {
      LocationPurpose.report => (
        'enviar',
        'Ela mostra onde fica o buraco. O app só lê a localização agora, para este reporte.',
        'Sem ela, não dá para mostrar onde fica o buraco. Permita a localização para enviar o '
            'reporte.',
        'enviar o reporte',
      ),
      LocationPurpose.vote => (
        'votar',
        'Ela confere se você está perto do buraco. A localização não fica guardada.',
        'Sem ela, não dá para conferir se você está perto do buraco. Permita a localização para '
            'votar.',
        'votar',
      ),
      LocationPurpose.nearby => (
        'ver os reportes perto',
        'Ela mostra os buracos reportados perto de você. O app só lê a localização agora, sem '
            'guardar.',
        'Sem ela, não dá para achar os reportes perto de você. Permita a localização para ver a '
            'lista.',
        'ver os reportes perto de você',
      ),
    };

    final (icon, title, text, action) = switch (reading.status) {
      LocationStatus.idle => (
        Icons.location_on_outlined,
        'Localização',
        'A localização do aparelho é lida junto com a foto.',
        null,
      ),
      LocationStatus.capturing => (
        Icons.my_location,
        'Buscando a sua localização',
        'Fique num lugar aberto, se puder.',
        null,
      ),
      LocationStatus.ready => (
        Icons.location_on,
        'Localização encontrada',
        accuracy ?? '',
        ('Atualizar localização', onRefresh),
      ),
      LocationStatus.inaccurate => (
        Icons.location_searching,
        'A localização está imprecisa',
        '${accuracy ?? ''}. Para $goal, ela precisa ser de até $limit m: tente num lugar aberto, '
            'longe de prédios e árvores.',
        ('Atualizar localização', onRefresh),
      ),
      LocationStatus.mocked => (
        Icons.location_disabled,
        'A localização parece falsa',
        'Ela veio de um app de localização simulada. Desligue o app e tente de novo.',
        ('Atualizar localização', onRefresh),
      ),
      LocationStatus.permissionNeeded => (
        Icons.location_on_outlined,
        'Precisamos da sua localização',
        permissionReason,
        ('Permitir a localização', onRequestPermission),
      ),
      LocationStatus.permissionDenied => (
        Icons.location_off_outlined,
        'Sem a permissão da localização',
        deniedReason,
        ('Permitir a localização', onRequestPermission),
      ),
      LocationStatus.permissionDeniedForever => (
        Icons.location_off_outlined,
        'A localização está bloqueada',
        'Libere a localização para o app nas configurações do aparelho e volte aqui.',
        ('Abrir as configurações', onOpenAppSettings),
      ),
      LocationStatus.serviceDisabled => (
        Icons.location_off_outlined,
        'A localização do aparelho está desligada',
        'Ligue a localização para $serviceGoal.',
        ('Ativar a localização', onOpenLocationSettings),
      ),
      LocationStatus.failed => (
        Icons.location_searching,
        'Não encontramos a sua localização',
        'Tente num lugar aberto, longe de prédios e árvores.',
        ('Atualizar localização', onRefresh),
      ),
    };
    final isBlocking = switch (reading.status) {
      LocationStatus.idle || LocationStatus.capturing || LocationStatus.ready => false,
      _ => true,
    };
    final foreground = isBlocking ? colors.onErrorContainer : colors.onSurface;

    return Card(
      margin: EdgeInsets.zero,
      color: isBlocking ? colors.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // O leitor de tela anuncia a mudança da localização, como "Localização encontrada".
            Semantics(
              liveRegion: true,
              child: MergeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reading.status == LocationStatus.capturing)
                      const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(icon, color: isBlocking ? foreground : colors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(color: foreground),
                          ),
                          if (text.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              text,
                              style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (action case (final label, final onPressed)) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: isBlocking
                    ? FilledButton.tonal(
                        onPressed: onPressed,
                        style: AppTheme.tonalButtonStyle,
                        child: Text(label),
                      )
                    : TextButton(onPressed: onPressed, child: Text(label)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
