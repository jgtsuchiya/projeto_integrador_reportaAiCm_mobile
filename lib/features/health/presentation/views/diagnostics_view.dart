import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/config/app_config_provider.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/core/utils/date_formatters.dart';
import 'package:reportaai_cm/core/widgets/error_view.dart';
import 'package:reportaai_cm/core/widgets/loading_indicator.dart';
import 'package:reportaai_cm/core/widgets/primary_button.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';
import 'package:reportaai_cm/features/health/domain/models/health_status.dart';
import 'package:reportaai_cm/features/health/presentation/view_models/diagnostics_view_model.dart';

/// Diagnóstico da conexão com a API (`/diagnostico`, só em debug): o endereço usado e o resultado
/// do `GET /api/health`. Serve para conferir o `env/dev.json` em cada aparelho.
class DiagnosticsView extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiBaseUrl = ref.watch(appConfigProvider).apiBaseUrl;
    final health = ref.watch(diagnosticsViewModelProvider);
    void refresh() => ref.read(diagnosticsViewModelProvider.notifier).refresh();

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnóstico da API')),
      body: SafeArea(
        child: ScrollableCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ApiAddress(apiBaseUrl: apiBaseUrl),
              const SizedBox(height: 24),
              health.when(
                // O "Conferir de novo" também mostra o carregando.
                skipLoadingOnRefresh: false,
                loading: () => const LoadingIndicator(message: 'Conferindo a API...'),
                error: (error, _) => ErrorView(
                  title: 'A API não respondeu',
                  message: ApiException.messageOf(error),
                  onRetry: refresh,
                ),
                data: (status) => _HealthResult(status: status, onRefresh: refresh),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApiAddress extends StatelessWidget {
  const new({required this.apiBaseUrl});

  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Endereço da API', style: textTheme.labelLarge),
            const SizedBox(height: 4),
            SelectableText(apiBaseUrl, style: textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text(
              'Para trocar, edite a API_URL do env/dev.json e rode o app de novo.',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthResult extends StatelessWidget {
  const new({required this.status, required this.onRefresh});

  final HealthStatus status;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          status.isOk ? Icons.check_circle_outline : Icons.warning_amber,
          size: 48,
          color: status.isOk ? theme.colorScheme.primary : theme.colorScheme.error,
        ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            status.status,
            style: theme.textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A API respondeu em ${formatDateTime(status.checkedAt.toLocal())}.',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Conferir de novo', onPressed: onRefresh),
      ],
    );
  }
}
