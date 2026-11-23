import 'package:reportaai_cm/features/reports/domain/models/geo_location.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';

/// O JSON do reporte (seção 5 do plano dos reportes do backend), o mesmo no `POST`, no `PATCH`, no
/// detalhe e nos itens das listas. Os campos que o app ainda não usa, como o `votes.mine` e o
/// `canVote` da validação, ficam de fora.
final class ReportDto {
  const new(this._report);

  /// Lança uma [FormatException] quando um campo falta ou está fora do formato. A mensagem diz só
  /// o nome do campo, nunca o valor, que pode ser a descrição ou uma coordenada (RM27). O
  /// `callApi` a converte em `ServerException`.
  factory fromJson(Object? json) {
    final report = _object(json, 'reporte');
    final location = _object(report['location'], 'location');
    final photo = _object(report['photo'], 'photo');
    final votes = _object(report['votes'], 'votes');

    return ReportDto(
      Report(
        id: _read(report, 'id'),
        status: ReportStatus.fromApiName(_read(report, 'status')),
        description: _read(report, 'description'),
        location: GeoLocation(
          latitude: _readDouble(location, 'location.latitude'),
          longitude: _readDouble(location, 'location.longitude'),
          accuracyMeters: _readDouble(location, 'location.accuracyMeters'),
        ),
        photo: ReportPhotoInfo(
          id: _read(photo, 'photo.id'),
          width: _readInt(photo, 'photo.width'),
          height: _readInt(photo, 'photo.height'),
        ),
        votes: ReportVotes(
          confirmations: _readInt(votes, 'votes.confirmations'),
          rejections: _readInt(votes, 'votes.rejections'),
          confirmationsRequired: _readInt(votes, 'votes.confirmationsRequired'),
          rejectionsRequired: _readInt(votes, 'votes.rejectionsRequired'),
        ),
        isMine: _read(report, 'isMine'),
        canEdit: _read(report, 'canEdit'),
        canDelete: _read(report, 'canDelete'),
        createdAt: _readDateTime(report, 'createdAt') ?? (throw _invalidField('createdAt')),
        updatedAt: _readDateTime(report, 'updatedAt') ?? (throw _invalidField('updatedAt')),
        statusChangedAt: _readDateTime(report, 'statusChangedAt'),
        distanceMeters: report['distanceMeters'] == null
            ? null
            : _readInt(report, 'distanceMeters'),
      ),
    );
  }

  final Report _report;

  Report toModel() => _report;
}

Map<String, Object?> _object(Object? json, String name) => switch (json) {
  final Map<String, Object?> object => object,
  _ => throw FormatException('O campo "$name" do reporte está fora do formato esperado.'),
};

/// O campo [path] (o último trecho é a chave) com o tipo [T]. Com um [T] que aceita `null`, o
/// campo ausente vira `null`.
T _read<T>(Map<String, Object?> json, String path) => switch (json[_key(path)]) {
  final T value => value,
  _ => throw _invalidField(path),
};

double _readDouble(Map<String, Object?> json, String path) => switch (json[_key(path)]) {
  final num value when value.isFinite => value.toDouble(),
  _ => throw _invalidField(path),
};

int _readInt(Map<String, Object?> json, String path) => switch (json[_key(path)]) {
  final int value => value,
  final double value when value == value.truncateToDouble() => value.toInt(),
  _ => throw _invalidField(path),
};

/// Uma data com hora, em ISO 8601 (ex.: `2026-11-09T14:30:00.000Z`). Fica em UTC, como veio.
DateTime? _readDateTime(Map<String, Object?> json, String path) =>
    switch (_read<String?>(json, path)) {
      null => null,
      final value => DateTime.tryParse(value) ?? (throw _invalidField(path)),
    };

String _key(String path) => path.split('.').last;

FormatException _invalidField(String path) =>
    FormatException('O campo "$path" do reporte está fora do formato esperado.');
