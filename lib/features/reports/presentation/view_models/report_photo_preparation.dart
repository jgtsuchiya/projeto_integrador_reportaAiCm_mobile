import 'dart:typed_data';

import 'package:reportaai_cm/core/media/image_compressor.dart';
import 'package:reportaai_cm/features/reports/domain/models/prepared_photo.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_limits.dart';

/// A mensagem da foto que não pôde ser usada: a que a câmera não tratou, ou que a API recusou
/// (o 400 de um campo da foto e o 413).
const photoNotUsableMessage = 'Não foi possível usar esta foto. Tire outra.';

/// Trata a foto da câmera para o envio (RM22), como a abertura e a edição do reporte fazem: a
/// foto com o maior lado em 1600 px (JPEG 80, até a qualidade 60 para caber em 2 MB) e a
/// miniatura com 400 px (JPEG 70, até 50 para caber em 100 KB), na orientação certa e sem o EXIF.
///
/// A miniatura sai da foto já tratada: o aparelho decodifica menos pixels, e a orientação já está
/// nos pixels. Lança a `ImageCompressionException` quando o aparelho não trata a imagem e a
/// [InvalidReportPhotoException] quando o resultado não segue as regras da API.
Future<PreparedPhoto> prepareReportPhoto(ImageCompressor compressor, Uint8List original) async {
  final photo = await compressor.compressToFit(
    original,
    maxSide: ReportLimits.photoMaxSide,
    quality: ReportLimits.photoQuality,
    maxBytes: ReportLimits.photoMaxBytes,
    minQuality: ReportLimits.photoMinQuality,
  );
  final thumbnail = await compressor.compressToFit(
    photo.bytes,
    maxSide: ReportLimits.thumbnailMaxSide,
    quality: ReportLimits.thumbnailQuality,
    maxBytes: ReportLimits.thumbnailMaxBytes,
    minQuality: ReportLimits.thumbnailMinQuality,
  );

  return PreparedPhoto.create(photo: photo.bytes, thumbnail: thumbnail.bytes);
}
