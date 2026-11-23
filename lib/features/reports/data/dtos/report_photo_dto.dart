import 'package:reportaai_cm/features/reports/domain/models/jpeg_base64.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_draft.dart';

/// A resposta do `GET /api/reports/:id/photo`: `{ id, mimeType, content }`, com o `content` em
/// base64.
final class ReportPhotoDto {
  const new({required this.id, required this.content});

  /// Lança uma [FormatException] quando falta um campo. O base64 só é lido no [toModel].
  factory fromJson(Object? json) {
    if (json case {'id': final String id, 'content': final String content}) {
      return ReportPhotoDto(id: id, content: content);
    }
    throw const FormatException('A foto do reporte está fora do formato esperado.');
  }

  final String id;

  /// O JPEG em base64.
  final String content;

  /// A imagem em bytes, pelo `decodeJpegBase64`. Lança a [FormatException] quando o `content` não
  /// é base64 ou não é um JPEG.
  ReportPhotoImage toModel() => ReportPhotoImage(id: id, bytes: decodeJpegBase64(content));
}
