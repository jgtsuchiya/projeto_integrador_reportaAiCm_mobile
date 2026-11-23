import 'package:reportaai_cm/features/reports/domain/models/geo_location.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_draft.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_limits.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_page.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';

/// Os reportes de buracos, nas rotas de `/api/reports`. A implementação que chama a API fica em
/// `data/`, e os testes usam o `FakeReportRepository`.
///
/// Os métodos lançam uma `ApiException` (de `core/network`): a `ValidationException` no 400, com o
/// campo (ex.: `photo.content` ou `description`), a `NotFoundException` no reporte que não existe
/// ou que o cidadão não vê (RN35), a `BusinessRuleException` no 422, com a `message` do motivo, a
/// `NetworkException` sem conexão e a `ServerException` no 5xx e no 413.
abstract interface class ReportRepository {
  /// Abre o reporte (`POST /api/reports`), com a [idempotencyKey] no header `Idempotency-Key`:
  /// repetir com a mesma chave depois de uma falha devolve o reporte já criado, sem abrir outro
  /// (RN31 e RM24). A foto vai em base64, com o tempo limite de 60 s.
  Future<Report> create(ReportDraft draft, {required String idempotencyKey});

  /// Os reportes do cidadão (`GET /api/reports/mine`), do mais novo ao mais antigo, na [page]
  /// (a partir de 1), só com o [status], se passado.
  Future<ReportPage> listMine({
    int page = 1,
    int pageSize = ReportLimits.pageSize,
    ReportStatus? status,
  });

  /// Os reportes em validação e confirmados de qualquer cidadão a até [radiusMeters] do [point]
  /// (`GET /api/reports/nearby`), do mais perto ao mais longe, cada um com o `distanceMeters`.
  Future<List<Report>> listNearby(GeoPoint point, {required int radiusMeters});

  /// O reporte (`GET /api/reports/:id`).
  Future<Report> getById(String id);

  /// A foto ou a miniatura do reporte (`GET /api/reports/:id/photo`), já em bytes.
  Future<ReportPhotoImage> getPhoto(String reportId, ReportPhotoSize size);

  /// Muda a descrição e a foto do reporte (`PATCH /api/reports/:id`), só o que está nas
  /// [changes], e devolve o reporte atualizado. Lança a `BusinessRuleException` (422) quando o
  /// reporte já recebeu votos ou saiu da validação (RN33).
  Future<Report> update(String id, ReportChanges changes);

  /// Exclui o reporte (`DELETE /api/reports/:id`). Lança a `BusinessRuleException` (422) quando o
  /// reporte saiu da validação (RN34).
  Future<void> delete(String id);
}
