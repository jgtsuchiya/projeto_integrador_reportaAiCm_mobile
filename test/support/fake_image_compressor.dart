import 'dart:async';
import 'dart:typed_data';

import 'package:reportaai_cm/core/media/image_compressor.dart';

import 'sample_images.dart';

/// Um pedido ao [FakeImageCompressor], com o tamanho dos bytes recebidos.
typedef CompressCall = ({int inputLength, int maxSide, int quality, int maxBytes, int minQuality});

/// Fake do [ImageCompressor], escrito à mão como os fakes dos repositórios. Devolve a [photo]
/// para a foto do reporte (o `maxSide` maior que o de uma miniatura) e a [thumbnail] para a
/// miniatura, e guarda os pedidos em [calls].
final class FakeImageCompressor implements ImageCompressor {
  /// A foto tratada: a de 160 x 120 px, se o teste não trocar.
  Uint8List photo = samplePhotoJpeg;

  /// A miniatura tratada: a de 40 x 30 px, se o teste não trocar.
  Uint8List thumbnail = sampleThumbnailJpeg;

  /// Lançado no próximo pedido, como a imagem que o aparelho não trata.
  ImageCompressionException? error;

  /// Enquanto não é completado, o tratamento fica pendente: é o "Preparando a foto".
  Completer<void>? pending;

  final calls = <CompressCall>[];

  @override
  Future<CompressedImage> compressToFit(
    Uint8List bytes, {
    required int maxSide,
    required int quality,
    required int maxBytes,
    required int minQuality,
  }) async {
    calls.add((
      inputLength: bytes.length,
      maxSide: maxSide,
      quality: quality,
      maxBytes: maxBytes,
      minQuality: minQuality,
    ));

    final pending = this.pending;
    if (pending != null) await pending.future;

    final error = this.error;
    if (error != null) throw error;

    final isThumbnail = maxSide <= 480;
    return CompressedImage(
      bytes: isThumbnail ? thumbnail : photo,
      width: isThumbnail ? 40 : 160,
      height: isThumbnail ? 30 : 120,
      quality: quality,
    );
  }
}
