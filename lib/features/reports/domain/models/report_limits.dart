/// Os limites dos reportes, iguais aos padrões da API (as variáveis `REPORT_*` do backend e as
/// constantes do domínio dele). Se a API mudar um padrão, o valor muda aqui também.
abstract final class ReportLimits {
  /// A descrição, opcional, de até 500 caracteres (RN27).
  static const descriptionMaxLength = 500;

  /// A pior precisão aceita, em metros, na abertura e no voto (`REPORT_MAX_ACCURACY_METERS`).
  static const maxAccuracyMeters = 50;

  /// O raio da busca do reporte repetido, antes do envio (RM23).
  static const duplicateRadiusMeters = 30;

  /// O raio dos "Reportes perto de você" e a distância máxima do voto (RM28).
  static const nearbyRadiusMeters = 500;

  /// Os reportes de cada página de "Meus reportes".
  static const pageSize = 20;

  /// O tamanho máximo da foto, depois do tratamento (`REPORT_PHOTO_MAX_BYTES`, 2 MB).
  static const int photoMaxBytes = 2 * 1024 * 1024;

  /// O tamanho máximo da miniatura (`REPORT_THUMBNAIL_MAX_BYTES`, 100 KB).
  static const int thumbnailMaxBytes = 100 * 1024;

  /// O maior lado que a API aceita na foto e na miniatura, em pixels (RN29).
  static const photoMaxDimension = 2048;
  static const thumbnailMaxDimension = 480;

  /// Como o app trata a foto (RM22): o maior lado, a qualidade do JPEG e a menor qualidade das
  /// tentativas, quando a foto passa do tamanho. Ficam abaixo dos limites da API, com folga.
  static const photoMaxSide = 1600;
  static const photoQuality = 80;
  static const photoMinQuality = 60;

  /// Como o app trata a miniatura das listas.
  static const thumbnailMaxSide = 400;
  static const thumbnailQuality = 70;
  static const thumbnailMinQuality = 50;
}
