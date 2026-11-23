import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/media/flutter_image_compressor.dart';
import 'package:reportaai_cm/core/media/image_compressor.dart';
import 'package:reportaai_cm/core/media/image_compressor_provider.dart';

import '../../support/sample_images.dart';

/// O pacote no lugar do aparelho: cada qualidade gera uma imagem com o tamanho do mapa, e o teste
/// confere os pedidos.
final class _FakeCompression {
  new(this.sizeByQuality);

  final Map<int, int> sizeByQuality;
  final requests = <({int minWidth, int minHeight, int quality})>[];

  Future<Uint8List> call(
    Uint8List image, {
    required int minWidth,
    required int minHeight,
    required int quality,
  }) async {
    requests.add((minWidth: minWidth, minHeight: minHeight, quality: quality));
    return Uint8List(sizeByQuality[quality] ?? 10);
  }
}

void main() {
  group('shortSideFor', () {
    test('deve pedir o menor lado que deixa o maior no limite, na horizontal e na vertical', () {
      expect(shortSideFor(4000, 3000, maxSide: 1600), 1200);
      expect(shortSideFor(3000, 4000, maxSide: 1600), 1200);
      expect(shortSideFor(4032, 3024, maxSide: 400), 300);
    });

    test('deve arredondar para baixo, para o maior lado nunca passar', () {
      // 1600 * 1080 / 1920 = 900; 1600 * 1000 / 3001 = 533,15...
      expect(shortSideFor(1920, 1080, maxSide: 1600), 900);
      expect(shortSideFor(3001, 1000, maxSide: 1600), 533);
    });

    test('deve manter a imagem que já cabe, sem aumentar', () {
      expect(shortSideFor(800, 600, maxSide: 1600), 600);
      expect(shortSideFor(1600, 1600, maxSide: 1600), 1600);
    });

    test('deve pedir pelo menos 1 px numa imagem muito estreita', () {
      expect(shortSideFor(100000, 1, maxSide: 400), 1);
    });
  });

  group('FlutterImageCompressor', () {
    Future<({int width, int height})> sizeOf(Uint8List bytes) async =>
        bytes.length > 1000 ? (width: 4000, height: 3000) : (width: 1600, height: 1200);

    test('deve pedir a proporção certa e devolver na primeira qualidade que cabe', () async {
      final compression = _FakeCompression({80: 900});
      final sut = FlutterImageCompressor(compress: compression.call, readSize: sizeOf);

      final result = await sut.compressToFit(
        Uint8List(5000),
        maxSide: 1600,
        quality: 80,
        maxBytes: 1000,
        minQuality: 60,
      );

      expect(compression.requests, [(minWidth: 1200, minHeight: 1200, quality: 80)]);
      expect(result.bytes, hasLength(900));
      expect((result.width, result.height, result.quality), (1600, 1200, 80));
    });

    test('deve baixar a qualidade de 10 em 10 até caber (RM22)', () async {
      final compression = _FakeCompression({80: 1500, 70: 1200, 60: 1000});
      final sut = FlutterImageCompressor(
        compress: compression.call,
        readSize: (bytes) async => (width: 1600, height: 1200),
      );

      final result = await sut.compressToFit(
        Uint8List(5000),
        maxSide: 1600,
        quality: 80,
        maxBytes: 1000,
        minQuality: 60,
      );

      expect([for (final request in compression.requests) request.quality], [80, 70, 60]);
      expect((result.bytes.length, result.quality), (1000, 60));
    });

    test('deve parar na qualidade mínima e devolver a última tentativa, mesmo grande', () async {
      final compression = _FakeCompression({70: 3000, 60: 2500, 55: 2000});
      final sut = FlutterImageCompressor(
        compress: compression.call,
        readSize: (bytes) async => (width: 400, height: 300),
      );

      final result = await sut.compressToFit(
        Uint8List(10),
        maxSide: 400,
        quality: 70,
        maxBytes: 1000,
        minQuality: 55,
      );

      expect([for (final request in compression.requests) request.quality], [70, 60, 55]);
      expect((result.bytes.length, result.quality), (2000, 55));
    });

    test('deve converter a falha do pacote na ImageCompressionException', () async {
      final sut = FlutterImageCompressor(
        compress: (image, {required minWidth, required minHeight, required quality}) =>
            throw PlatformException(code: 'decode'),
        readSize: (bytes) async => (width: 10, height: 10),
      );

      await expectLater(
        sut.compressToFit(Uint8List(10), maxSide: 400, quality: 70, maxBytes: 10, minQuality: 50),
        throwsA(
          isA<ImageCompressionException>().having(
            (error) => error.cause,
            'cause',
            isA<PlatformException>(),
          ),
        ),
      );
    });

    test('deve converter a imagem que o sistema não lê na ImageCompressionException', () async {
      final sut = FlutterImageCompressor(
        compress: _FakeCompression({}).call,
        readSize: (bytes) async => throw Exception('imagem inválida'),
      );

      await expectLater(
        sut.compressToFit(Uint8List(10), maxSide: 400, quality: 70, maxBytes: 10, minQuality: 50),
        throwsA(isA<ImageCompressionException>()),
      );
    });

    test('não deve mostrar os bytes no texto do resultado e do erro (RM27)', () {
      final image = CompressedImage(bytes: Uint8List(3), width: 2, height: 1, quality: 80);

      expect(image.toString(), 'CompressedImage(3 bytes, 2x1, quality: 80)');
      expect(image, image);
      expect(image.hashCode, image.hashCode);
      expect(
        const ImageCompressionException('detalhe').toString(),
        'ImageCompressionException: a imagem não pôde ser tratada.',
      );
    });
  });

  group('readEncodedImageSize', () {
    test('deve ler as dimensões do JPEG pelo cabeçalho', () async {
      expect(await readEncodedImageSize(samplePhotoJpeg), (width: 160, height: 120));
    });

    test('deve ler também o PNG', () async {
      expect(await readEncodedImageSize(samplePng), (width: 16, height: 12));
    });
  });

  group('imageCompressorProvider', () {
    test('deve fornecer a implementação pelo flutter_image_compress', () {
      final container = ProviderContainer.test();

      expect(container.read(imageCompressorProvider), isA<FlutterImageCompressor>());
    });
  });
}
