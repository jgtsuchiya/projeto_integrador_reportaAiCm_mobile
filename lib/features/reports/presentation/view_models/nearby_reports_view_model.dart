import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/core/location/location_service.dart';
import 'package:reportaai_cm/core/location/location_service_provider.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_limits.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_location.dart';
import 'package:reportaai_cm/features/reports/reports_providers.dart';

/// Estado da tela "Reportes perto de você": a localização, a lista e os erros.
final NotifierProvider<NearbyReportsViewModel, NearbyReportsState> nearbyReportsViewModelProvider =
    NotifierProvider.autoDispose(NearbyReportsViewModel.new);

/// Os reportes da validação (RM28), a partir da busca dos reportes perto: só os em validação e de
/// outros cidadãos (a API traz também os confirmados e os do próprio cidadão), do mais perto ao
/// mais longe, com os já votados no fim.
List<Report> reportsToValidate(Iterable<Report> nearby) => arrangeNearbyReports(
  nearby.where((report) => report.status == ReportStatus.pending && !report.isMine),
);

/// Os [reports] na ordem da lista: primeiro os que ainda esperam o voto do cidadão, depois os que
/// ele já votou, cada grupo do mais perto ao mais longe. Com a mesma distância, a ordem da API.
List<Report> arrangeNearbyReports(Iterable<Report> reports) {
  final indexed = reports.indexed.toList()
    ..sort((a, b) {
      final byVote = _votedRank(a.$2).compareTo(_votedRank(b.$2));
      if (byVote != 0) return byVote;
      final byDistance = (a.$2.distanceMeters ?? 0).compareTo(b.$2.distanceMeters ?? 0);
      return byDistance != 0 ? byDistance : a.$1.compareTo(b.$1);
    });
  return List.unmodifiable([for (final (_, report) in indexed) report]);
}

int _votedRank(Report report) => report.votes.mine == null ? 0 : 1;

@immutable
final class NearbyReportsState {
  const new({
    this.location = const LocationReading(LocationStatus.capturing),
    this.items,
    this.isLoading = false,
    this.loadError,
  });

  /// A localização do aparelho. Sem servir (imprecisa, simulada, sem permissão, GPS desligado ou
  /// não encontrada), a tela mostra o motivo no lugar da lista. Pronta, fica sem a posição: ela só
  /// serve para a busca.
  final LocationReading location;

  /// Os reportes para validar, na ordem do [arrangeNearbyReports]. `null` até a primeira busca
  /// chegar, e quando a localização não serve.
  final List<Report>? items;

  /// A localização ou a lista estão sendo buscadas: na abertura, no "Atualizar" e no puxar para
  /// atualizar. A lista que já está na tela continua durante a busca.
  final bool isLoading;

  /// A mensagem da busca da lista que falhou. Com uma lista já na tela, ela continua.
  final String? loadError;

  @override
  bool operator ==(Object other) =>
      other is NearbyReportsState &&
      other.location == location &&
      _sameItems(other.items, items) &&
      other.isLoading == isLoading &&
      other.loadError == loadError;

  @override
  int get hashCode =>
      Object.hash(location, items == null ? null : Object.hashAll(items!), isLoading, loadError);

  @override
  String toString() =>
      'NearbyReportsState(location: ${location.status.name}, items: ${items?.length}, '
      'isLoading: $isLoading, loadError: $loadError)';
}

/// "Reportes perto de você" (RM28): lê a localização atual, com as regras da abertura (RM21), e
/// busca os reportes a até 500 m (`GET /api/reports/nearby`). Depois de um voto, troca o reporte
/// pelo da resposta, sem buscar a lista de novo (RM30).
final class NearbyReportsViewModel extends Notifier<NearbyReportsState> {
  /// Conta as buscas: o resultado de uma busca atropelada (o "Atualizar" no meio da anterior) é
  /// descartado.
  var _run = 0;

  @override
  NearbyReportsState build() {
    unawaited(Future.microtask(load));
    return const NearbyReportsState(isLoading: true);
  }

  /// Lê a localização e busca a lista: na abertura, no "Atualizar", no "Atualizar localização" e
  /// no puxar para atualizar. A lista que já está na tela continua durante a busca e se a busca
  /// falhar, mas sai se a localização não servir mais.
  Future<void> load() => _load(readReportLocation);

  /// "Permitir a localização", depois da explicação da tela.
  Future<void> requestLocationPermission() => _load(requestReportLocation);

  /// "Abrir as configurações", com a permissão negada para sempre.
  Future<void> openAppSettings() async {
    await ref.read(locationServiceProvider).openAppSettings();
  }

  /// "Ativar a localização", com o GPS desligado.
  Future<void> openLocationSettings() async {
    await ref.read(locationServiceProvider).openLocationSettings();
  }

  /// O app voltou para o primeiro plano: com a localização bloqueada pelas configurações, busca de
  /// novo, porque o cidadão pode ter acabado de liberar.
  Future<void> onResume() async {
    const blockedBySettings = {
      LocationStatus.permissionDeniedForever,
      LocationStatus.serviceDisabled,
    };
    if (blockedBySettings.contains(state.location.status)) await load();
  }

  /// Troca o reporte da lista pelo [report] da API, como o que volta do voto, sem buscar a lista
  /// de novo (RM30). A distância continua a da busca, e o reporte votado vai para o fim, marcado.
  void replaceReport(Report report) {
    final items = state.items;
    if (items == null || !items.any((item) => item.id == report.id)) return;

    state = _copy(
      items: arrangeNearbyReports([
        for (final item in items)
          if (item.id == report.id)
            report.withDistanceMeters(report.distanceMeters ?? item.distanceMeters)
          else
            item,
      ]),
    );
  }

  /// Tira o reporte [reportId] da lista: ele não existe mais para o cidadão (404).
  void removeReport(String reportId) {
    final items = state.items;
    if (items == null) return;

    state = _copy(items: List.unmodifiable(items.where((item) => item.id != reportId)));
  }

  Future<void> _load(Future<LocationReading> Function(LocationService service) read) async {
    // A tela pode ter fechado antes da primeira busca começar.
    if (!ref.mounted) return;

    final run = ++_run;
    final hasList = state.items != null;
    state = NearbyReportsState(
      // Sem a lista na tela, o cartão da localização mostra a busca. Com ela, a lista continua.
      location: hasList ? state.location : const LocationReading(LocationStatus.capturing),
      items: state.items,
      isLoading: true,
    );

    final reading = await read(ref.read(locationServiceProvider));
    if (!ref.mounted || run != _run) return;

    final location = reading.location;
    if (!reading.status.isReady || location == null) {
      state = NearbyReportsState(location: reading);
      return;
    }

    // A localização serve: a tela passa do "Buscando a sua localização" para a busca da lista.
    state = NearbyReportsState(
      location: const LocationReading(LocationStatus.ready),
      items: state.items,
      isLoading: true,
    );

    try {
      final nearby = await ref
          .read(reportRepositoryProvider)
          .listNearby(location.point, radiusMeters: ReportLimits.nearbyRadiusMeters);
      if (!ref.mounted || run != _run) return;

      state = NearbyReportsState(
        location: const LocationReading(LocationStatus.ready),
        items: reportsToValidate(nearby),
      );
    } on Object catch (error) {
      if (!ref.mounted || run != _run) return;

      state = NearbyReportsState(
        location: const LocationReading(LocationStatus.ready),
        items: state.items,
        loadError: ApiException.messageOf(error),
      );
    }
  }

  NearbyReportsState _copy({List<Report>? items}) => NearbyReportsState(
    location: state.location,
    items: items ?? state.items,
    isLoading: state.isLoading,
    loadError: state.loadError,
  );
}

bool _sameItems(List<Report>? a, List<Report>? b) =>
    identical(a, b) || (a != null && b != null && listEquals(a, b));
