import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/routes.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';

/// Tela inicial provisória, até o épico de login: o nome do app e, em debug, o atalho para o
/// diagnóstico da API.
class HomeView extends StatelessWidget {
  const new({this.showDiagnostics = kDebugMode, super.key});

  /// Segue a rota de diagnóstico, que só existe em debug.
  final bool showDiagnostics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('ReportaAi Cm')),
      body: SafeArea(
        child: ScrollableCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_road, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'ReportaAi Cm',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Reporte os buracos no asfalto de Campo Mourão.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'O app está em construção: o login e os reportes chegam nas próximas versões.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (showDiagnostics) ...[
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => unawaited(context.push(AppRoutes.diagnostics)),
                  icon: const Icon(Icons.monitor_heart_outlined),
                  label: const Text('Diagnóstico da API'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
