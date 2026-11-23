import 'package:reportaai_cm/features/reports/domain/models/geo_location.dart';
import 'package:reportaai_cm/features/reports/domain/models/jpeg_base64.dart';
import 'package:reportaai_cm/features/reports/domain/models/prepared_photo.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_draft.dart';
import 'package:reportaai_cm/features/reports/domain/models/vote_type.dart';

/// O corpo do `POST /api/reports`: a descrição, a localização e a foto em base64.
final class OpenReportRequestDto {
  const new(this.draft);

  final ReportDraft draft;

  /// A foto grande vira um texto de até 2,7 MB: quem envia chama fora da thread da tela.
  Map<String, Object?> toJson() => {
    'description': ?draft.description,
    'location': _location(draft.location),
    'photo': _photo(draft.photo),
  };
}

/// O corpo do `PATCH /api/reports/:id`: só o que muda. A descrição vazia (`""`) apaga a atual, e
/// a localização nunca vai: ela não muda (RM25).
final class EditReportRequestDto {
  const new(this.changes);

  final ReportChanges changes;

  Map<String, Object?> toJson() => {
    'description': ?changes.description,
    if (changes.photo case final photo?) 'photo': _photo(photo),
  };
}

/// O corpo do `POST /api/reports/:id/votes`: o voto e a localização atual do aparelho, que a API só
/// confere e não guarda (RN38).
final class VoteRequestDto {
  const new(this.vote, this.location);

  final VoteType vote;
  final GeoLocation location;

  Map<String, Object?> toJson() => {'vote': vote.apiName, 'location': _location(location)};
}

Map<String, Object?> _location(GeoLocation location) => {
  'latitude': location.latitude,
  'longitude': location.longitude,
  'accuracyMeters': location.accuracyMeters,
};

Map<String, Object?> _photo(PreparedPhoto photo) => {
  'content': encodeJpegBase64(photo.photo),
  'thumbnail': encodeJpegBase64(photo.thumbnail),
};
