import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:reportaai_cm/features/reports/domain/models/jpeg.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_limits.dart';

/// As duas imagens do reporte, com os campos do corpo da API.
enum ReportImageKind {
  photo('A foto', 'photo.content', ReportLimits.photoMaxBytes, ReportLimits.photoMaxDimension),
  thumbnail(
    'A miniatura',
    'photo.thumbnail',
    ReportLimits.thumbnailMaxBytes,
    ReportLimits.thumbnailMaxDimension,
  );

  new(this.label, this.apiField, this.maxBytes, this.maxDimension);

  /// Como a imagem aparece na mensagem: "A foto passa de 2 MB.".
  final String label;

  /// O campo no corpo e no `details` dos erros da API.
  final String apiField;

  final int maxBytes;

  /// O maior lado, em pixels.
  final int maxDimension;
}

/// O que impede o envio de uma imagem, nas regras da API (RN29).
enum ReportImageProblem {
  /// Não é um JPEG: outra imagem, um JPEG cortado ou um arquivo qualquer.
  notJpeg,

  /// Passa do tamanho máximo.
  tooHeavy,

  /// Passa do maior lado.
  tooLarge,
}

/// Uma das imagens não segue as regras da API. Com o tratamento do app, não deveria acontecer: a
/// tela pede outra foto.
final class InvalidReportPhotoException implements Exception {
  const new(this.kind, this.problem);

  final ReportImageKind kind;
  final ReportImageProblem problem;

  /// A mesma mensagem da API para o problema, como "A foto passa de 2 MB.".
  String get message => switch (problem) {
    ReportImageProblem.notJpeg => '${kind.label} precisa ser uma imagem JPEG.',
    ReportImageProblem.tooHeavy => '${kind.label} passa de ${_formatByteSize(kind.maxBytes)}.',
    ReportImageProblem.tooLarge => '${kind.label} passa de ${kind.maxDimension} px no maior lado.',
  };

  @override
  String toString() => 'InvalidReportPhotoException: $message';
}

/// A foto do reporte pronta para o envio (RM22): a foto e a miniatura em JPEG, sem os metadados e
/// dentro dos limites da API (RN29). Só nasce pelo [PreparedPhoto.create], que confere as duas: uma
/// instância é sempre uma foto que a API aceita.
@immutable
final class PreparedPhoto {
  const new _({
    required this.photo,
    required this.thumbnail,
    required this.width,
    required this.height,
  });

  /// Confere as duas imagens, nesta ordem, como a API: a assinatura do JPEG, o tamanho, a
  /// estrutura e o maior lado. Os segmentos de metadados que sobrarem saem, como a API também
  /// faz. Lança a [InvalidReportPhotoException] com a primeira imagem recusada.
  factory create({required Uint8List photo, required Uint8List thumbnail}) {
    final checkedPhoto = _check(photo, ReportImageKind.photo);
    final checkedThumbnail = _check(thumbnail, ReportImageKind.thumbnail);

    return PreparedPhoto._(
      photo: checkedPhoto.bytes,
      thumbnail: checkedThumbnail.bytes,
      width: checkedPhoto.width,
      height: checkedPhoto.height,
    );
  }

  /// A foto, com o maior lado de até 1600 px no tratamento do app.
  final Uint8List photo;

  /// A miniatura das listas, com o maior lado de até 400 px.
  final Uint8List thumbnail;

  /// As dimensões da foto.
  final int width;
  final int height;

  @override
  bool operator ==(Object other) =>
      other is PreparedPhoto &&
      identical(other.photo, photo) &&
      identical(other.thumbnail, thumbnail);

  @override
  int get hashCode => Object.hash(identityHashCode(photo), identityHashCode(thumbnail));

  // Sem os bytes, que são a foto (RM27).
  @override
  String toString() =>
      'PreparedPhoto(${width}x$height, foto com ${photo.length} bytes, miniatura com '
      '${thumbnail.length} bytes)';
}

JpegImage _check(Uint8List bytes, ReportImageKind kind) {
  // A assinatura vem antes do tamanho, como na API: um PNG grande recebe a mensagem do formato.
  if (!hasJpegSignature(bytes)) {
    throw InvalidReportPhotoException(kind, ReportImageProblem.notJpeg);
  }
  if (bytes.length > kind.maxBytes) {
    throw InvalidReportPhotoException(kind, ReportImageProblem.tooHeavy);
  }

  final jpeg = parseJpeg(bytes);
  if (jpeg == null) throw InvalidReportPhotoException(kind, ReportImageProblem.notJpeg);

  final longSide = jpeg.width > jpeg.height ? jpeg.width : jpeg.height;
  if (longSide > kind.maxDimension) {
    throw InvalidReportPhotoException(kind, ReportImageProblem.tooLarge);
  }
  return jpeg;
}

/// O tamanho como nas mensagens da API: `2 MB` e `100 KB` (1 KB = 1024 bytes).
String _formatByteSize(int bytes) {
  const kilobyte = 1024;
  const megabyte = 1024 * kilobyte;

  String decimal(double value) {
    final cut = (value * 10).floor() / 10;
    final text = cut == cut.truncateToDouble() ? cut.toInt().toString() : cut.toString();
    return text.replaceAll('.', ',');
  }

  if (bytes >= megabyte) return '${decimal(bytes / megabyte)} MB';
  if (bytes >= kilobyte) return '${decimal(bytes / kilobyte)} KB';
  return bytes == 1 ? '1 byte' : '$bytes bytes';
}
