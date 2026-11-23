import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/routes.dart';
import 'package:reportaai_cm/core/widgets/error_view.dart';
import 'package:reportaai_cm/core/widgets/loading_indicator.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/widgets/email_verification_notice.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_limits.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/nearby_reports_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_location.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/nearby_report_item.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/report_location_card.dart';

/// "Reportes perto de você" (`/reportes/perto`, RM28): os reportes em validação de outros cidadãos
/// a até 500 m da posição atual, do mais perto ao mais longe, cada um com o "Está lá" e o "Não está
/// lá". Os que o cidadão já votou ficam no fim, marcados.
///
/// Sem a localização que serve, a tela mostra o motivo e a ação que resolve, como na abertura do
/// reporte. O "Atualizar" e o puxar para atualizar leem a localização e buscam a lista de novo.
/// Sem o e-mail confirmado, a lista aparece sem o voto, com o aviso do reenvio em cima (RM20).
class NearbyReportsView extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<NearbyReportsView> createState() => _NearbyReportsViewState();
}

class _NearbyReportsViewState extends ConsumerState<NearbyReportsView> {
  final _refreshIndicator = GlobalKey<RefreshIndicatorState>();
  late final AppLifecycleListener _lifecycle;

  NearbyReportsViewModel get _viewModel => ref.read(nearbyReportsViewModelProvider.notifier);

  @override
  void initState() {
    super.initState();
    // Na volta das configurações do aparelho, a localização liberada é lida de novo.
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_viewModel.onResume()));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// "Atualizar": com a lista na tela, o carregando do puxar para atualizar aparece em cima dela.
  void _refresh() {
    final indicator = _refreshIndicator.currentState;
    if (indicator != null) {
      unawaited(indicator.show());
    } else {
      unawaited(_viewModel.load());
    }
  }

  /// O detalhe, com a distância da busca: o `GET /api/reports/:id` não a traz.
  void _open(Report report) =>
      unawaited(context.push(AppRoutes.reportDetail(report.id), extra: report.distanceMeters));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nearbyReportsViewModelProvider);
    final items = state.items;
    final location = state.location;
    final isEmailVerified = switch (ref.watch(authControllerProvider)) {
      AuthAuthenticated(:final profile) => profile.emailVerifiedAt != null,
      _ => true,
    };

    final Widget content;
    if (items != null) {
      content = RefreshIndicator(
        key: _refreshIndicator,
        onRefresh: _viewModel.load,
        child: items.isEmpty
            ? _Fill(child: _EmptyList(onRefresh: _refresh))
            : _ReportList(
                items: items,
                loadError: state.loadError,
                showEmailNotice: !isEmailVerified,
                onOpen: _open,
              ),
      );
    } else if (location.status == LocationStatus.capturing) {
      content = const LoadingIndicator(message: 'Buscando a sua localização');
    } else if (!location.status.isReady) {
      content = RefreshIndicator(
        onRefresh: _viewModel.load,
        child: _Fill(
          child: ReportLocationCard(
            reading: location,
            purpose: LocationPurpose.nearby,
            onRefresh: () => unawaited(_viewModel.load()),
            onRequestPermission: () => unawaited(_viewModel.requestLocationPermission()),
            onOpenAppSettings: () => unawaited(_viewModel.openAppSettings()),
            onOpenLocationSettings: () => unawaited(_viewModel.openLocationSettings()),
          ),
        ),
      );
    } else if (state.loadError case final error?) {
      content = ErrorView(
        title: 'Os reportes não carregaram',
        message: error,
        onRetry: () => unawaited(_viewModel.load()),
      );
    } else {
      content = const LoadingIndicator(message: 'Carregando os reportes perto de você');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes perto de você'),
        actions: [
          IconButton(
            onPressed: state.isLoading ? null : _refresh,
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(child: content),
    );
  }
}

class _ReportList extends StatelessWidget {
  const new({
    required this.items,
    required this.loadError,
    required this.showEmailNotice,
    required this.onOpen,
  });

  final List<Report> items;
  final String? loadError;
  final bool showEmailNotice;
  final ValueChanged<Report> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loadError = this.loadError;
    final header = [
      if (showEmailNotice) ...[
        const EmailVerificationNotice(),
        const SizedBox(height: 8),
        const Text('Depois de confirmar o e-mail, você pode votar nos reportes.'),
        const SizedBox(height: 16),
      ],
      if (loadError != null) ...[
        Semantics(
          liveRegion: true,
          child: Text(
            'A lista não foi atualizada. $loadError',
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error),
          ),
        ),
        const SizedBox(height: 12),
      ],
      Text(
        'Em validação a até ${ReportLimits.nearbyRadiusMeters} m de você, do mais perto ao mais '
        'longe. Vote só nos buracos que você estiver vendo.',
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 12),
    ];

    return ListView.builder(
      // O puxar para atualizar funciona também quando tudo cabe na tela, sem rolar.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _Centered(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: header),
          );
        }

        final report = items[index - 1];
        // Com a chave, o item que vai para o fim depois do voto leva o estado junto.
        return _Centered(
          key: ValueKey(report.id),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NearbyReportItem(report: report, onTap: () => onOpen(report)),
          ),
        );
      },
    );
  }
}

/// A lista vazia.
class _EmptyList extends StatelessWidget {
  const new({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.near_me_outlined, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          'Nenhum reporte em validação perto de você.',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Quando alguém reportar um buraco a até ${ReportLimits.nearbyRadiusMeters} m daqui, ele '
          'aparece nesta lista.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Atualizar'),
        ),
      ],
    );
  }
}

/// O conteúdo centralizado na área inteira, que rola com a fonte grande e puxa para atualizar.
class _Fill extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: ScrollableCenter.maxContentWidth),
              child: Padding(padding: const EdgeInsets.all(24), child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Limita a largura do item, para a lista não esticar no tablet e na horizontal.
class _Centered extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: ScrollableCenter.maxContentWidth),
      child: child,
    ),
  );
}
