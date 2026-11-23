import 'dart:async';

import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/reports/domain/models/geo_location.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_draft.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_limits.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_page.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';
import 'package:reportaai_cm/features/reports/domain/models/vote_type.dart';
import 'package:reportaai_cm/features/reports/domain/repositories/report_repository.dart';

import 'sample_images.dart';

/// O reporte do exemplo da seção 5 do plano dos reportes do backend, como a API o devolve, já com
/// o `votes.mine` e o `canVote` da validação.
const reportJson = <String, Object?>{
  'id': '8f0e2c4a-6b1d-4c7e-9a52-3d6f1e0b7a91',
  'status': 'PENDING',
  'description': 'Buraco grande na faixa da direita, perto do semáforo.',
  'location': {'latitude': -24.045812, 'longitude': -52.378901, 'accuracyMeters': 9},
  'photo': {'id': 'c1b7d0e2-2f4a-4b8e-9d61-5a3c7e8f9b10', 'width': 1600, 'height': 1200},
  'votes': {
    'confirmations': 3,
    'rejections': 0,
    'confirmationsRequired': 10,
    'rejectionsRequired': 10,
    'mine': null,
  },
  'isMine': true,
  'canEdit': false,
  'canDelete': true,
  'canVote': false,
  'createdAt': '2026-11-09T14:30:00.000Z',
  'updatedAt': '2026-11-09T14:30:00.000Z',
  'statusChangedAt': null,
};

/// O [reportJson] como modelo.
final sampleReport = Report(
  id: '8f0e2c4a-6b1d-4c7e-9a52-3d6f1e0b7a91',
  status: ReportStatus.pending,
  description: 'Buraco grande na faixa da direita, perto do semáforo.',
  location: const GeoLocation(latitude: -24.045812, longitude: -52.378901, accuracyMeters: 9),
  photo: const ReportPhotoInfo(
    id: 'c1b7d0e2-2f4a-4b8e-9d61-5a3c7e8f9b10',
    width: 1600,
    height: 1200,
  ),
  votes: const ReportVotes(
    confirmations: 3,
    rejections: 0,
    confirmationsRequired: 10,
    rejectionsRequired: 10,
  ),
  isMine: true,
  canEdit: false,
  canDelete: true,
  createdAt: DateTime.utc(2026, 11, 9, 14, 30),
  updatedAt: DateTime.utc(2026, 11, 9, 14, 30),
);

/// O [sampleReport] com os campos trocados. O [id] também troca o id da foto, para cada reporte
/// ter a sua no cache.
Report sampleReportWith({
  String? id,
  ReportStatus? status,
  String? description,
  bool clearDescription = false,
  String? photoId,
  int? confirmations,
  int? rejections,
  bool? isMine,
  bool? canEdit,
  bool? canDelete,
  bool? canVote,
  VoteType? myVote,
  DateTime? createdAt,
  DateTime? statusChangedAt,
  int? distanceMeters,
}) => Report(
  id: id ?? sampleReport.id,
  status: status ?? sampleReport.status,
  description: clearDescription ? null : description ?? sampleReport.description,
  location: sampleReport.location,
  photo: ReportPhotoInfo(
    id: photoId ?? (id == null ? sampleReport.photo.id : 'foto-$id'),
    width: sampleReport.photo.width,
    height: sampleReport.photo.height,
  ),
  votes: ReportVotes(
    confirmations: confirmations ?? sampleReport.votes.confirmations,
    rejections: rejections ?? sampleReport.votes.rejections,
    confirmationsRequired: sampleReport.votes.confirmationsRequired,
    rejectionsRequired: sampleReport.votes.rejectionsRequired,
    mine: myVote,
  ),
  isMine: isMine ?? sampleReport.isMine,
  canEdit: canEdit ?? sampleReport.canEdit,
  canDelete: canDelete ?? sampleReport.canDelete,
  canVote: canVote ?? sampleReport.canVote,
  createdAt: createdAt ?? sampleReport.createdAt,
  updatedAt: sampleReport.updatedAt,
  statusChangedAt: statusChangedAt,
  distanceMeters: distanceMeters,
);

/// Os reportes do cidadão, do mais novo ao mais antigo, com [count] itens: `reporte-1` é o mais
/// novo. Todos em validação, sem votos, e o cidadão pode editar e excluir.
List<Report> myReports(int count) => [
  for (var index = 1; index <= count; index++)
    sampleReportWith(
      id: 'reporte-$index',
      description: 'Buraco $index',
      confirmations: 0,
      canEdit: true,
      createdAt: DateTime.utc(2026, 11, 20).subtract(Duration(hours: index)),
    ),
];

/// Um reporte em validação aberto por outro cidadão, a [distanceMeters] daqui, como o `nearby`
/// devolve. Sem o voto do cidadão, ele pode votar ([canVote]); com o [myVote], não.
Report othersReport({
  String id = 'reporte-de-outro',
  int? distanceMeters = 12,
  String? description,
  int? confirmations,
  int? rejections,
  ReportStatus? status,
  VoteType? myVote,
  bool? canVote,
}) => sampleReportWith(
  id: id,
  status: status,
  description: description,
  confirmations: confirmations,
  rejections: rejections,
  isMine: false,
  canEdit: false,
  canDelete: false,
  canVote: canVote ?? (myVote == null && (status ?? ReportStatus.pending) == ReportStatus.pending),
  myVote: myVote,
  distanceMeters: distanceMeters,
);

/// Fake do [ReportRepository], escrito à mão como os outros fakes, com os reportes em memória,
/// como a API: a abertura entra no começo dos [mine], a edição troca a descrição e a foto (com um
/// id novo), a exclusão tira o reporte, e o voto soma a contagem e muda o status no limite, como a
/// API (RN39). Cada método tem o erro e a espera da próxima chamada, e as chamadas ficam guardadas
/// para o teste conferir.
final class FakeReportRepository implements ReportRepository {
  /// Os reportes do cidadão, do mais novo ao mais antigo.
  List<Report> mine = [];

  /// Os reportes de outros cidadãos que o cidadão vê (o detalhe por id).
  List<Report> others = [];

  /// A resposta do `listNearby`, como a API: do mais perto ao mais longe.
  List<Report> nearby = [];

  Exception? createError;
  Completer<void>? createPending;
  final createCalls = <({ReportDraft draft, String idempotencyKey})>[];

  Exception? listMineError;
  Completer<void>? listMinePending;
  final listMineCalls = <({int page, int pageSize, ReportStatus? status})>[];

  Exception? nearbyError;
  Completer<void>? nearbyPending;
  final nearbyCalls = <({GeoPoint point, int radiusMeters})>[];

  Exception? getByIdError;
  Completer<void>? getByIdPending;
  final getByIdCalls = <String>[];

  Exception? photoError;
  Completer<void>? photoPending;
  final photoCalls = <({String reportId, ReportPhotoSize size})>[];

  Exception? updateError;
  Completer<void>? updatePending;
  final updateCalls = <({String id, ReportChanges changes})>[];

  Exception? deleteError;
  Completer<void>? deletePending;
  final deleteCalls = <String>[];

  Exception? voteError;
  Completer<void>? votePending;
  final voteCalls = <({String id, VoteType vote, GeoLocation location})>[];

  /// Os reportes criados por chave, para a repetição com a mesma `Idempotency-Key` (RN31).
  final _byIdempotencyKey = <String, Report>{};
  var _nextId = 1;

  @override
  Future<Report> create(ReportDraft draft, {required String idempotencyKey}) async {
    createCalls.add((draft: draft, idempotencyKey: idempotencyKey));
    await _settle(createPending, createError);

    final existing = _byIdempotencyKey[idempotencyKey];
    if (existing != null) return existing;

    final id = 'novo-${_nextId++}';
    final report = Report(
      id: id,
      status: ReportStatus.pending,
      description: draft.description,
      location: GeoLocation(
        latitude: draft.location.latitude,
        longitude: draft.location.longitude,
        accuracyMeters: draft.location.accuracyMeters.ceilToDouble(),
      ),
      photo: ReportPhotoInfo(id: 'foto-$id', width: draft.photo.width, height: draft.photo.height),
      votes: const ReportVotes(
        confirmations: 0,
        rejections: 0,
        confirmationsRequired: 10,
        rejectionsRequired: 10,
      ),
      isMine: true,
      canEdit: true,
      canDelete: true,
      createdAt: DateTime.utc(2026, 11, 21, 10),
      updatedAt: DateTime.utc(2026, 11, 21, 10),
    );
    mine = [report, ...mine];
    return _byIdempotencyKey[idempotencyKey] = report;
  }

  @override
  Future<ReportPage> listMine({
    int page = 1,
    int pageSize = ReportLimits.pageSize,
    ReportStatus? status,
  }) async {
    listMineCalls.add((page: page, pageSize: pageSize, status: status));
    await _settle(listMinePending, listMineError);

    final filtered = [
      for (final report in mine)
        if (status == null || report.status == status) report,
    ];
    final start = (page - 1) * pageSize;
    return ReportPage(
      items: filtered.skip(start).take(pageSize).toList(),
      page: page,
      pageSize: pageSize,
      total: filtered.length,
    );
  }

  @override
  Future<List<Report>> listNearby(GeoPoint point, {required int radiusMeters}) async {
    nearbyCalls.add((point: point, radiusMeters: radiusMeters));
    await _settle(nearbyPending, nearbyError);

    return [
      for (final report in nearby)
        if ((report.distanceMeters ?? 0) <= radiusMeters) report,
    ];
  }

  @override
  Future<Report> getById(String id) async {
    getByIdCalls.add(id);
    await _settle(getByIdPending, getByIdError);

    return _find(id) ?? (throw const NotFoundException(message: 'Reporte não encontrado.'));
  }

  @override
  Future<ReportPhotoImage> getPhoto(String reportId, ReportPhotoSize size) async {
    photoCalls.add((reportId: reportId, size: size));
    await _settle(photoPending, photoError);

    final report = _find(reportId);
    if (report == null) throw const NotFoundException(message: 'Reporte não encontrado.');

    return ReportPhotoImage(
      id: report.photo.id,
      bytes: size == ReportPhotoSize.full ? samplePhotoJpeg : sampleThumbnailJpeg,
    );
  }

  @override
  Future<Report> update(String id, ReportChanges changes) async {
    updateCalls.add((id: id, changes: changes));
    await _settle(updatePending, updateError);

    final report = _find(id);
    if (report == null) throw const NotFoundException(message: 'Reporte não encontrado.');

    final updated = Report(
      id: report.id,
      status: report.status,
      description: switch (changes.description) {
        null => report.description,
        '' => null,
        final description => description,
      },
      location: report.location,
      photo: switch (changes.photo) {
        final photo? => ReportPhotoInfo(
          id: '${report.photo.id}-nova',
          width: photo.width,
          height: photo.height,
        ),
        null => report.photo,
      },
      votes: report.votes,
      isMine: report.isMine,
      canEdit: report.canEdit,
      canDelete: report.canDelete,
      createdAt: report.createdAt,
      updatedAt: DateTime.utc(2026, 11, 22, 9),
      statusChangedAt: report.statusChangedAt,
    );
    mine = [
      for (final item in mine)
        if (item.id == id) updated else item,
    ];
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    deleteCalls.add(id);
    await _settle(deletePending, deleteError);

    mine = [...mine.where((report) => report.id != id)];
  }

  @override
  Future<Report> vote(String id, VoteType vote, GeoLocation location) async {
    voteCalls.add((id: id, vote: vote, location: location));
    await _settle(votePending, voteError);

    final report = _find(id);
    if (report == null) throw const NotFoundException(message: 'Reporte não encontrado.');

    final votes = report.votes;
    final confirmations = votes.confirmations + (vote == VoteType.confirm ? 1 : 0);
    final rejections = votes.rejections + (vote == VoteType.deny ? 1 : 0);
    final status = confirmations >= votes.confirmationsRequired
        ? ReportStatus.confirmed
        : rejections >= votes.rejectionsRequired
        ? ReportStatus.rejected
        : report.status;

    // Como a API: o reporte do voto volta sem a distância.
    final voted = Report(
      id: report.id,
      status: status,
      description: report.description,
      location: report.location,
      photo: report.photo,
      votes: ReportVotes(
        confirmations: confirmations,
        rejections: rejections,
        confirmationsRequired: votes.confirmationsRequired,
        rejectionsRequired: votes.rejectionsRequired,
        mine: vote,
      ),
      isMine: report.isMine,
      canEdit: false,
      canDelete: false,
      createdAt: report.createdAt,
      updatedAt: DateTime.utc(2026, 11, 22, 10),
      statusChangedAt: status == report.status
          ? report.statusChangedAt
          : DateTime.utc(2026, 11, 22, 10),
    );
    others = [
      for (final item in others)
        if (item.id == id) voted else item,
    ];
    nearby = [
      for (final item in nearby)
        if (item.id == id) voted.withDistanceMeters(item.distanceMeters) else item,
    ];
    return voted;
  }

  Report? _find(String id) {
    for (final report in [...mine, ...others, ...nearby]) {
      if (report.id == id) return report;
    }
    return null;
  }

  /// Espera o [pending], se houver, e lança o [error], se houver.
  Future<void> _settle(Completer<void>? pending, Exception? error) async {
    if (pending != null) await pending.future;
    if (error != null) throw error;
  }
}
