import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Uma imagem JPEG lida pelo [parseJpeg]: as dimensões do cabeçalho e os bytes sem os metadados.
@immutable
final class JpegImage {
  const new({required this.width, required this.height, required this.bytes});

  final int width;
  final int height;

  /// Os bytes sem os segmentos de metadados (EXIF, XMP e IPTC).
  final Uint8List bytes;

  @override
  bool operator ==(Object other) =>
      other is JpegImage &&
      other.width == width &&
      other.height == height &&
      _sameBytes(other.bytes, bytes);

  @override
  int get hashCode => Object.hash(width, height, bytes.length);

  @override
  String toString() => 'JpegImage(${width}x$height, ${bytes.length} bytes)';
}

/// Se os bytes têm a assinatura do JPEG: o início da imagem seguido de outro marcador
/// (`FF D8 FF`) e o fim (`FF D9`). É a primeira conferência da API (RN29).
bool hasJpegSignature(Uint8List bytes) =>
    bytes.length >= 4 &&
    bytes[0] == _markerPrefix &&
    bytes[1] == _startOfImage &&
    bytes[2] == _markerPrefix &&
    bytes[bytes.length - 2] == _markerPrefix &&
    bytes[bytes.length - 1] == _endOfImage;

/// Lê o JPEG como o `ReportImage` da API: confere a assinatura, percorre os segmentos do
/// cabeçalho até o início dos dados da imagem (SOS), lê as dimensões do quadro (SOF, no JPEG
/// baseline e no progressivo) e deixa de fora os segmentos de metadados: o APP1 (EXIF e XMP), que
/// pode ter o GPS e o modelo do aparelho, e o APP13 (IPTC). O APP0 (JFIF) e o APP2 (perfil de cor)
/// ficam, e o que vem a partir do SOS é copiado como está.
///
/// Devolve `null` quando os bytes não são um JPEG: outra imagem (PNG, WebP, HEIC), um JPEG
/// cortado ou um arquivo qualquer.
JpegImage? parseJpeg(Uint8List bytes) {
  if (!hasJpegSignature(bytes)) return null;

  final kept = <Uint8List>[Uint8List.sublistView(bytes, 0, 2)];
  ({int width, int height})? frame;
  var offset = 2;

  while (offset < bytes.length) {
    final segmentStart = offset;
    if (bytes[offset] != _markerPrefix) return null;

    // Bytes de preenchimento (FF) podem vir antes do marcador.
    while (offset < bytes.length && bytes[offset] == _markerPrefix) {
      offset++;
    }
    if (offset >= bytes.length) return null;

    final marker = bytes[offset++];
    if (_isStandalone(marker)) {
      kept.add(Uint8List.sublistView(bytes, segmentStart, offset));
      continue;
    }

    // Um segundo início, o fim antes dos dados da imagem ou um byte que não é marcador.
    if (marker == 0x00 || marker == _startOfImage || marker == _endOfImage) return null;
    if (offset + 2 > bytes.length) return null;

    // O tamanho inclui os dois bytes dele mesmo.
    final length = (bytes[offset] << 8) | bytes[offset + 1];
    final end = offset + length;
    if (length < 2 || end > bytes.length) return null;

    if (_isStartOfFrame(marker) && frame == null) {
      // Precisão (1 byte), altura (2), largura (2) e quantidade de componentes (1).
      if (length < 8) return null;

      final height = (bytes[offset + 3] << 8) | bytes[offset + 4];
      final width = (bytes[offset + 5] << 8) | bytes[offset + 6];
      if (width == 0 || height == 0) return null;

      frame = (width: width, height: height);
    }

    if (marker == _startOfScan) {
      if (frame == null) return null;

      kept.add(Uint8List.sublistView(bytes, segmentStart));
      return JpegImage(width: frame.width, height: frame.height, bytes: _concat(kept));
    }

    if (!_metadataMarkers.contains(marker)) {
      kept.add(Uint8List.sublistView(bytes, segmentStart, end));
    }
    offset = end;
  }

  return null;
}

const _markerPrefix = 0xff;
const _startOfImage = 0xd8;
const _endOfImage = 0xd9;
const _startOfScan = 0xda;

/// Os segmentos de metadados que saem: APP1 (EXIF e XMP) e APP13 (IPTC).
const _metadataMarkers = {0xe1, 0xed};

/// Início de quadro (SOF0 a SOF15), menos os marcadores DHT (C4), JPG (C8) e DAC (CC).
bool _isStartOfFrame(int marker) =>
    marker >= 0xc0 && marker <= 0xcf && marker != 0xc4 && marker != 0xc8 && marker != 0xcc;

/// Marcadores sem tamanho: RST0 a RST7 e TEM.
bool _isStandalone(int marker) => (marker >= 0xd0 && marker <= 0xd7) || marker == 0x01;

Uint8List _concat(List<Uint8List> parts) {
  final result = Uint8List(parts.fold(0, (total, part) => total + part.length));
  var offset = 0;
  for (final part in parts) {
    result.setRange(offset, offset + part.length, part);
    offset += part.length;
  }
  return result;
}

bool _sameBytes(Uint8List a, Uint8List b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}
