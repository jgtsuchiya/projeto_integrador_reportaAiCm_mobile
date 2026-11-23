import 'package:meta/meta.dart';
import 'package:reportaai_cm/features/reports/domain/models/geo_location.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';

/// A foto do reporte, sem as imagens: o id e as dimensões. As imagens vêm pelo
/// `ReportRepository.getPhoto`.
@immutable
final class ReportPhotoInfo {
  const new({required this.id, required this.width, required this.height});

  /// Muda quando a foto é trocada: o cache das fotos usa o id como chave, e nunca mostra a antiga.
  final String id;
  final int width;
  final int height;

  @override
  bool operator ==(Object other) =>
      other is ReportPhotoInfo && other.id == id && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(id, width, height);

  @override
  String toString() => 'ReportPhotoInfo($id, ${width}x$height)';
}

/// As contagens da validação e quantos votos o reporte precisa, para "3 de 10 confirmações".
@immutable
final class ReportVotes {
  const new({
    required this.confirmations,
    required this.rejections,
    required this.confirmationsRequired,
    required this.rejectionsRequired,
  });

  final int confirmations;
  final int rejections;
  final int confirmationsRequired;
  final int rejectionsRequired;

  /// O progresso das confirmações, de 0 a 1, para a barra.
  double get confirmationProgress => confirmationsRequired <= 0
      ? 0
      : (confirmations / confirmationsRequired).clamp(0, 1).toDouble();

  @override
  bool operator ==(Object other) =>
      other is ReportVotes &&
      other.confirmations == confirmations &&
      other.rejections == rejections &&
      other.confirmationsRequired == confirmationsRequired &&
      other.rejectionsRequired == rejectionsRequired;

  @override
  int get hashCode =>
      Object.hash(confirmations, rejections, confirmationsRequired, rejectionsRequired);

  @override
  String toString() =>
      'ReportVotes($confirmations de $confirmationsRequired confirmações, $rejections de '
      '$rejectionsRequired negativas)';
}

/// Um reporte de buraco, como a API devolve para o cidadão da sessão. Nunca traz quem abriu o
/// reporte: o [isMine] basta (RM27).
///
/// O [canEdit] e o [canDelete] vêm calculados pela API: o app mostra as ações a partir deles e
/// não repete as regras (RM25).
@immutable
final class Report {
  const new({
    required this.id,
    required this.status,
    required this.location,
    required this.photo,
    required this.votes,
    required this.isMine,
    required this.canEdit,
    required this.canDelete,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.statusChangedAt,
    this.distanceMeters,
  });

  final String id;
  final ReportStatus status;

  /// A descrição, sem os espaços das pontas, ou `null` quando o reporte não tem.
  final String? description;

  /// Onde o buraco está, com a precisão do aparelho de quem abriu. Não muda depois da abertura.
  final GeoLocation location;

  final ReportPhotoInfo photo;
  final ReportVotes votes;

  /// Se o cidadão da sessão abriu o reporte.
  final bool isMine;

  final bool canEdit;
  final bool canDelete;

  /// Em UTC, como a API devolve.
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Quando o reporte saiu da validação (virou confirmado ou descartado). `null` em validação.
  final DateTime? statusChangedAt;

  /// A distância, em metros, até o ponto da busca dos reportes perto. Só nessa busca.
  final int? distanceMeters;

  @override
  bool operator ==(Object other) =>
      other is Report &&
      other.id == id &&
      other.status == status &&
      other.description == description &&
      other.location == location &&
      other.photo == photo &&
      other.votes == votes &&
      other.isMine == isMine &&
      other.canEdit == canEdit &&
      other.canDelete == canDelete &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.statusChangedAt == statusChangedAt &&
      other.distanceMeters == distanceMeters;

  @override
  int get hashCode => Object.hash(
    id,
    status,
    description,
    location,
    photo,
    votes,
    isMine,
    canEdit,
    canDelete,
    createdAt,
    updatedAt,
    statusChangedAt,
    distanceMeters,
  );

  // Sem a descrição e as coordenadas, que podem identificar o lugar (RM27).
  @override
  String toString() =>
      'Report($id, ${status.name}, $votes, isMine: $isMine, canEdit: $canEdit, '
      'canDelete: $canDelete, distanceMeters: $distanceMeters)';
}
