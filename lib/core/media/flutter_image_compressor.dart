// Os argumentos da compressão são os padrões do pacote, escritos mesmo assim: a orientação, o EXIF
// e o formato são regras do app (RM22), e não podem mudar com uma versão nova do pacote.
// ignore_for_file: avoid_redundant_argument_values

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:reportaai_cm/core/media/image_compressor.dart';

/// A compressão do pacote, com a orientação aplicada e sem o EXIF. O `minWidth` e o `minHeight`
/// são do pacote: ele reduz a imagem até o menor lado chegar a eles, sem aumentar.
typedef CompressImage = Future<Uint8List> Function(
  Uint8List image, {
  required int minWidth,
  required int minHeight,
  required int quality,
});

/// As dimensões de uma imagem codificada (JPEG, HEIC ou PNG), lidas do cabeçalho.
typedef ReadImageSize = Future<({int width, int height})> Function(Uint8List bytes);

/// [ImageCompressor] pelo pacote `flutter_image_compress`, que trata a imagem no código nativo
/// (Android e iOS), fora da thread da tela. Os testes passam a compressão e a leitura das
/// dimensões falsas.
///
/// O pacote reduz a imagem pelo **menor** lado (o `minWidth` e o `minHeight`). Para o **maior**
/// lado chegar ao `maxSide`, o menor lado pedido sai da proporção da imagem, lida antes do
/// cabeçalho: uma foto de 4000 x 3000 px com o `maxSide` de 1600 pede o menor lado de 1200, e
/// sai com 1600 x 1200. A proporção não muda com a orientação, então o EXIF não atrapalha a conta.
final class FlutterImageCompressor implements ImageCompressor {
  new({CompressImage? compress, ReadImageSize? readSize})
    : _compress = compress ?? _compressWithPackage,
      _readSize = readSize ?? readEncodedImageSize;

  /// Quanto a qualidade cai a cada tentativa, quando a imagem passa do tamanho.
  static const qualityStep = 10;

  final CompressImage _compress;
  final ReadImageSize _readSize;

  @override
  Future<CompressedImage> compressToFit(
    Uint8List bytes, {
    required int maxSide,
    required int quality,
    required int maxBytes,
    required int minQuality,
  }) async {
    try {
      final source = await _readSize(bytes);
      final shortSide = shortSideFor(source.width, source.height, maxSide: maxSide);

      var attempt = quality;
      while (true) {
        final result = await _compress(
          bytes,
          minWidth: shortSide,
          minHeight: shortSide,
          quality: attempt,
        );
        final size = await _readSize(result);
        final image = CompressedImage(
          bytes: result,
          width: size.width,
          height: size.height,
          quality: attempt,
        );
        if (result.length <= maxBytes || attempt <= minQuality) return image;

        attempt = math.max(minQuality, attempt - qualityStep);
      }
    } on ImageCompressionException {
      rethrow;
    } on Object catch (error) {
      // O plugin falhou (uma imagem que ele não lê, ou a falta de memória): a tela pede outra foto.
      throw ImageCompressionException(error);
    }
  }
}

/// O menor lado a pedir ao pacote para o maior lado da imagem de [width] x [height] ficar em até
/// [maxSide]. Com a imagem já dentro do limite, é o menor lado dela: o pacote não muda o tamanho.
int shortSideFor(int width, int height, {required int maxSide}) {
  final longSide = math.max(width, height);
  final shortSide = math.min(width, height);
  if (longSide <= maxSide) return shortSide;

  // Arredondado para baixo: o maior lado nunca passa do limite.
  return math.max(1, maxSide * shortSide ~/ longSide);
}

/// As dimensões da imagem pelo `dart:ui`, que lê só o cabeçalho, sem decodificar os pixels.
Future<({int width, int height})> readEncodedImageSize(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      return (width: descriptor.width, height: descriptor.height);
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}

Future<Uint8List> _compressWithPackage(
  Uint8List image, {
  required int minWidth,
  required int minHeight,
  required int quality,
}) => FlutterImageCompress.compressWithList(
  image,
  minWidth: minWidth,
  minHeight: minHeight,
  quality: quality,
  // A orientação do EXIF vai para os pixels, e o EXIF sai (ele pode ter o GPS e o modelo do
  // aparelho, RM22).
  autoCorrectionAngle: true,
  keepExif: false,
  format: CompressFormat.jpeg,
);
