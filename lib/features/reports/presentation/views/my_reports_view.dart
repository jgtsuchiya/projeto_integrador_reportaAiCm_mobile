import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/routes.dart';
import 'package:reportaai_cm/core/widgets/error_view.dart';
import 'package:reportaai_cm/core/widgets/loading_indicator.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/my_reports_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/widgets/report_list_item.dart';

/// "Meus reportes" (`/reportes`): os reportes do cidadão, do mais novo ao mais antigo, com a
/// miniatura, o status em texto (RM26), as confirmações e a data. A lista carrega a página
/// seguinte perto do fim, o puxar para atualizar busca de novo, e o filtro mostra um status só.
class MyReportsView extends ConsumerStatefulWidget {
  const new({super.key});

  /// A distância do fim da lista em que a página seguinte começa a carregar.
  static const loadMoreThreshold = 600.0;

  @override
  ConsumerState<MyReportsView> createState() => _MyReportsViewState();
}

class _MyReportsViewState extends ConsumerState<MyReportsView> {
  final _scroll = ScrollController();

  MyReportsViewModel get _viewModel => ref.read(myReportsViewModelProvider.notifier);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadMoreNearTheEnd);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Perto do fim da lista, ou com a lista que não enche a tela, carrega a página seguinte.
  void _loadMoreNearTheEnd() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < MyReportsView.loadMoreThreshold) {
      unawaited(_viewModel.loadMore());
    }
  }

  void _openNewReport() => unawaited(context.push(AppRoutes.newReport));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myReportsViewModelProvider);
    final items = state.items;

    // Depois de cada página, a lista que não enche a tela não rola: confere o fim aqui.
    if (state.hasMore && !state.isLoadingMore && state.loadMoreError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadMoreNearTheEnd();
      });
    }

    final Widget content;
    if (items == null && state.loadError != null) {
      content = ErrorView(
        title: 'Os reportes não carregaram',
        message: state.loadError!,
        onRetry: () => unawaited(_viewModel.reload()),
      );
    } else if (items == null) {
      content = const LoadingIndicator(message: 'Carregando os reportes');
    } else {
      content = RefreshIndicator(
        onRefresh: _viewModel.reload,
        child: items.isEmpty
            ? _EmptyList(filter: state.filter, onNewReport: _openNewReport)
            : _ReportList(state: state, controller: _scroll, onRetryMore: _viewModel.loadMore),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Meus reportes')),
      floatingActionButton: items == null || items.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _openNewReport,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Novo reporte'),
            ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilterBar(
              selected: state.filter,
              onSelected: (filter) => unawaited(_viewModel.selectFilter(filter)),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

/// Os filtros por status, numa linha que rola de lado com a fonte grande.
class _FilterBar extends StatelessWidget {
  const new({required this.selected, required this.onSelected});

  final ReportFilter selected;
  final ValueChanged<ReportFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          for (final filter in ReportFilter.values) ...[
            ChoiceChip(
              label: Text(filter.label),
              selected: filter == selected,
              onSelected: (_) => onSelected(filter),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ReportList extends StatelessWidget {
  const new({required this.state, required this.controller, required this.onRetryMore});

  final MyReportsState state;
  final ScrollController controller;
  final Future<void> Function() onRetryMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = state.items!;
    final loadError = state.loadError;
    final loadMoreError = state.loadMoreError;
    final hasHeader = loadError != null;

    return ListView.builder(
      controller: controller,
      // O puxar para atualizar funciona também quando tudo cabe na tela, sem rolar.
      physics: const AlwaysScrollableScrollPhysics(),
      // Embaixo, espaço para o botão flutuante não cobrir o último reporte.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: items.length + 1 + (hasHeader ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasHeader && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                'A lista não foi atualizada. $loadError',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          );
        }

        final itemIndex = index - (hasHeader ? 1 : 0);
        if (itemIndex < items.length) {
          final report = items[itemIndex];
          return _Centered(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ReportListItem(
                report: report,
                onTap: () => unawaited(context.push(AppRoutes.reportDetail(report.id))),
              ),
            ),
          );
        }

        // O fim da lista: a página seguinte carregando, o erro dela ou nada.
        if (loadMoreError != null) {
          return _Centered(
            child: Column(
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    'Os próximos reportes não carregaram. $loadMoreError',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(
                  onPressed: () => unawaited(onRetryMore()),
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          );
        }
        if (state.isLoadingMore || state.hasMore) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(semanticsLabel: 'Carregando mais reportes'),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

/// A lista vazia, que também puxa para atualizar.
class _EmptyList extends StatelessWidget {
  const new({required this.filter, required this.onNewReport});

  final ReportFilter filter;
  final VoidCallback onNewReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAll = filter == ReportFilter.all;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: ScrollableCenter.maxContentWidth),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_road, size: 48, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      isAll
                          ? 'Você ainda não abriu nenhum reporte'
                          : 'Nenhum reporte ${_filterText(filter)}',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (isAll) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Viu um buraco na rua? Tire uma foto e reporte.',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: onNewReport,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Novo reporte'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _filterText(ReportFilter filter) => switch (filter) {
  ReportFilter.all => '',
  ReportFilter.pending => 'em validação',
  ReportFilter.confirmed => 'confirmado',
  ReportFilter.rejected => 'descartado',
};

/// Limita a largura do item, para a lista não esticar no tablet e na horizontal.
class _Centered extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: ScrollableCenter.maxContentWidth),
      child: child,
    ),
  );
}
