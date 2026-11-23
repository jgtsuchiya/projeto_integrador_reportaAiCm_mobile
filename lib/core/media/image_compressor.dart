import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Uma imagem JPEG tratada pelo [ImageCompressor]: os bytes, as dimensões e a qualidade que
/// coube no tamanho pedido.
@immutable
final class CompressedImage {
  const new({
    required this.bytes,
    required this.width,
    required this.height,
    required this.quality,
  });

  final Uint8List bytes;
  final int width;
  final int height;

  /// A qualidade do JPEG (de 0 a 100) da última tentativa.
  final int quality;

  @override
  bool operator ==(Object other) =>
      other is CompressedImage &&
      identical(other.bytes, bytes) &&
      other.width == width &&
      other.height == height &&
      other.quality == quality;

  @override
  int get hashCode => Object.hash(identityHashCode(bytes), width, height, quality);

  // Sem os bytes, que são a foto (RM27).
  @override
  String toString() =>
      'CompressedImage(${bytes.length} bytes, ${width}x$height, quality: $quality)';
}

/// O aparelho não conseguiu tratar a imagem, como um arquivo que não é imagem.
final class ImageCompressionException implements Exception {
  const new([this.cause]);

  final Object? cause;

  @override
  String toString() => 'ImageCompressionException: a imagem não pôde ser tratada.';
}

/// Redimensiona e comprime as imagens no código nativo do aparelho, fora da thread da tela. Só o
/// `core/media/` conhece o pacote, e os testes usam o `FakeImageCompressor`.
abstract interface class ImageCompressor {
  /// A imagem em JPEG com o maior lado de até [maxSide] px (uma menor não aumenta), na
  /// orientação certa (a do EXIF, aplicada nos pixels) e sem o EXIF.
  ///
  /// Começa na [quality] e, se o resultado passar de [maxBytes], tenta de novo com a qualidade
  /// menor, até a [minQuality]. A última tentativa volta mesmo se ainda passar: quem chama
  /// confere o tamanho. Lança a [ImageCompressionException] quando a imagem não pode ser tratada.
  Future<CompressedImage> compressToFit(
    Uint8List bytes, {
    required int maxSide,
    required int quality,
    required int maxBytes,
    required int minQuality,
  });
}
