import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:reportaai_cm/core/location/location_service.dart';
import 'package:reportaai_cm/core/location/location_service_provider.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';
import 'package:reportaai_cm/features/reports/domain/models/vote_type.dart';
import 'package:reportaai_cm/features/reports/domain/repositories/report_repository.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_location.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_refresh.dart';
import 'package:reportaai_cm/features/reports/reports_providers.dart';

/// Estado do voto num reporte, pelo id dele. O detalhe e o item dos "Reportes perto de você" do
/// mesmo reporte dividem o estado: o voto que começou num aparece no outro.
final NotifierProviderFamily<ReportVoteViewModel, ReportVoteState, String>
reportVoteViewModelProvider = NotifierProvider.autoDispose
    .family<ReportVoteViewModel, ReportVoteState, String>(ReportVoteViewModel.new);

/// Em que pé está o voto.
enum VoteStep {
  /// Nenhum voto em andamento: a tela mostra o "Está lá" e o "Não está lá".
  idle,

  /// O aparelho está lendo a localização atual, antes do envio.
  locating,

  /// O voto foi para a API.
  sending,

  /// A localização impediu o voto (imprecisa, simulada, sem permissão, GPS desligado ou não
  /// encontrada): a tela mostra o motivo e a ação que resolve, e o voto segue depois dela.
  blocked;

  /// Se o voto está em andamento: os botões ficam desativados.
  bool get isBusy => this == locating || this == sending;
}

@immutable
final class ReportVoteState {
  const new({this.step = VoteStep.idle, this.vote, this.location, this.message});

  final VoteStep step;

  /// O voto que o cidadão confirmou, enquanto ele é enviado ou espera a localização.
  final VoteType? vote;

  /// A leitura que impediu o voto, só no [VoteStep.blocked], para a tela mostrar o motivo. A
  /// posição que vai para a API nunca fica aqui: ela só existe durante o envio (RM29).
  final LocationReading? location;

  /// A mensagem do voto recusado pela API ou que falhou.
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is ReportVoteState &&
      other.step == step &&
      other.vote == vote &&
      other.location == location &&
      other.message == message;

  @override
  int get hashCode => Object.hash(step, vote, location, message);

  @override
  String toString() =>
      'ReportVoteState(${step.name}, vote: ${vote?.name}, location: ${location?.status.name}, '
      'message: $message)';
}

/// O voto do cidadão num reporte de outro cidadão (RM29 e RM30), depois da confirmação da tela:
/// lê a localização atual com as regras da abertura (a precisão de até 50 m e a posição de
/// verdade, RM21), envia o voto e atualiza as telas abertas com o reporte da resposta.
///
/// A localização vai só no corpo do voto: ela não fica no estado, nem no app, nem no log (RM29).
final class ReportVoteViewModel extends Notifier<ReportVoteState> {
  new(this.reportId);

  final String reportId;

  /// A mensagem que a tela mostra depois do voto, a partir do reporte da resposta.
  static String votedMessageFor(Report report) => switch (report.status) {
    ReportStatus.confirmed => 'Voto registrado. Com ele, o reporte foi confirmado.',
    ReportStatus.rejected => 'Voto registrado. Com ele, o reporte foi descartado.',
    _ => 'Voto registrado. Obrigado por ajudar a validar o reporte.',
  };

  @override
  ReportVoteState build() => const ReportVoteState();

  /// Lê a localização e envia o [vote], que o cidadão já confirmou. Devolve o reporte atualizado,
  /// ou `null` quando não votou (o motivo fica no estado). Com um voto em andamento, não faz nada.
  Future<Report?> vote(VoteType vote) => _send(vote, readReportLocation);

  /// "Atualizar localização", com o voto parado pela localização: lê de novo e, se ela servir,
  /// envia o voto que esperava.
  Future<Report?> refreshLocation() => _resume(readReportLocation);

  /// "Permitir a localização", depois da explicação da tela: pede a permissão e, aceita, envia o
  /// voto que esperava.
  Future<Report?> requestLocationPermission() => _resume(requestReportLocation);

  /// "Abrir as configurações", com a permissão negada para sempre.
  Future<void> openAppSettings() async {
    await ref.read(locationServiceProvider).openAppSettings();
  }

  /// "Ativar a localização", com o GPS desligado.
  Future<void> openLocationSettings() async {
    await ref.read(locationServiceProvider).openLocationSettings();
  }

  /// O app voltou para o primeiro plano: com o voto parado pelas configurações do aparelho, lê de
  /// novo, porque o cidadão pode ter acabado de liberar a localização.
  Future<Report?> onResume() async {
    const blockedBySettings = {
      LocationStatus.permissionDeniedForever,
      LocationStatus.serviceDisabled,
    };
    if (!blockedBySettings.contains(state.location?.status)) return null;
    return await _resume(readReportLocation);
  }

  /// "Cancelar", com o voto parado pela localização: o voto não vai.
  void cancel() {
    if (state.step == VoteStep.blocked) state = const ReportVoteState();
  }

  Future<Report?> _resume(Future<LocationReading> Function(LocationService) read) async {
    final vote = state.vote;
    if (state.step != VoteStep.blocked || vote == null) return null;
    return await _send(vote, read, resuming: true);
  }

  Future<Report?> _send(
    VoteType vote,
    Future<LocationReading> Function(LocationService) read, {
    bool resuming = false,
  }) async {
    if (state.step.isBusy || (state.step == VoteStep.blocked && !resuming)) return null;

    state = ReportVoteState(step: VoteStep.locating, vote: vote);
    final reading = await read(ref.read(locationServiceProvider));
    if (!ref.mounted) return null;

    final location = reading.location;
    if (!reading.status.isReady || location == null) {
      state = ReportVoteState(step: VoteStep.blocked, vote: vote, location: reading);
      return null;
    }

    state = ReportVoteState(step: VoteStep.sending, vote: vote);
    final repository = ref.read(reportRepositoryProvider);
    // Lido antes da chamada: as telas são atualizadas mesmo que esta feche no meio.
    final refresh = ref.read(reportRefreshProvider);

    final Report report;
    try {
      report = await repository.vote(reportId, vote, location);
    } on NotFoundException catch (error) {
      // O autor excluiu o reporte, ou ele saiu da validação e o cidadão não o vê mais (RN35).
      _fail(error.message);
      refresh.reportRemoved(reportId);
      return null;
    } on ConflictException catch (error) {
      // Já votou, em outro aparelho: a tela busca o reporte, para mostrar o voto dele.
      _fail(error.message);
      unawaited(_reload(repository, refresh));
      return null;
    } on BusinessRuleException catch (error) {
      // Longe demais, a precisão ruim, ou o reporte que saiu da validação nesse meio-tempo.
      _fail(error.message);
      unawaited(_reload(repository, refresh));
      return null;
    } on Object catch (error) {
      _fail(ApiException.messageOf(error));
      return null;
    }

    if (ref.mounted) state = const ReportVoteState();
    // Antes de atualizar as telas: o item dos reportes perto muda de lugar, e esta tela pode sair.
    refresh.reportUpdated(report);
    return report;
  }

  void _fail(String message) {
    if (ref.mounted) state = ReportVoteState(message: message);
  }

  /// Busca o reporte depois do voto recusado: a contagem, o status e o voto do cidadão podem ter
  /// mudado. A busca que falha não muda nada: o aviso do voto continua na tela.
  Future<void> _reload(ReportRepository repository, ReportRefresh refresh) async {
    try {
      refresh.reportUpdated(await repository.getById(reportId));
    } on NotFoundException {
      refresh.reportRemoved(reportId);
    } on Object {
      // A tela continua com o reporte que já tinha.
    }
  }
}
