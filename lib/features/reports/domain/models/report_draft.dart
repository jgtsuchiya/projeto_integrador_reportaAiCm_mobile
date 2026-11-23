import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:reportaai_cm/features/reports/domain/models/geo_location.dart';
import 'package:reportaai_cm/features/reports/domain/models/prepared_photo.dart';

/// Um reporte novo, pronto para o envio (`POST /api/reports`): a foto já tratada, a localização
/// do aparelho e a descrição opcional, já sem os espaços das pontas.
@immutable
final class ReportDraft {
  const new({required this.location, required this.photo, this.description});

  final GeoLocation location;
  final PreparedPhoto photo;
  final String? description;

  @override
  bool operator ==(Object other) =>
      other is ReportDraft &&
      other.location == location &&
      other.photo == photo &&
      other.description == description;

  @override
  int get hashCode => Object.hash(location, photo, description);

  @override
  String toString() => 'ReportDraft($location, $photo, com descrição: ${description != null})';
}

/// O que muda num reporte (`PATCH /api/reports/:id`): a descrição e a foto. A localização não muda
/// (RM25).
///
/// A [description] `null` não muda a descrição, e a vazia a apaga: "apagar" é diferente de "não
/// mudar".
@immutable
final class ReportChanges {
  const new({this.description, this.photo});

  /// `null`: não muda. Vazia: apaga. Senão, a descrição nova, já sem os espaços das pontas.
  final String? description;

  /// A foto nova, que substitui a anterior com outro id. `null`: não muda.
  final PreparedPhoto? photo;

  /// Se nada muda: a API recusa o corpo vazio, e o "Salvar" fica desativado.
  bool get isEmpty => description == null && photo == null;

  /// Se a descrição sai.
  bool get removesDescription => description != null && description!.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is ReportChanges && other.description == description && other.photo == photo;

  @override
  int get hashCode => Object.hash(description, photo);

  @override
  String toString() => 'ReportChanges(description: $description, photo: $photo)';
}

/// O tamanho da imagem do `GET /api/reports/:id/photo`. O [apiName] vai na query.
enum ReportPhotoSize {
  /// A foto, para o detalhe.
  full('full'),

  /// A miniatura, para as listas.
  thumbnail('thumbnail');

  new(this.apiName);

  final String apiName;
}

/// Uma imagem do reporte, já em bytes.
@immutable
final class ReportPhotoImage {
  const new({required this.id, required this.bytes});

  /// O id da foto, que muda quando ela é trocada.
  final String id;

  /// O JPEG, pronto para o `Image.memory`.
  final Uint8List bytes;

  @override
  bool operator ==(Object other) =>
      other is ReportPhotoImage && other.id == id && identical(other.bytes, bytes);

  @override
  int get hashCode => Object.hash(id, identityHashCode(bytes));

  @override
  String toString() => 'ReportPhotoImage($id, ${bytes.length} bytes)';
}
