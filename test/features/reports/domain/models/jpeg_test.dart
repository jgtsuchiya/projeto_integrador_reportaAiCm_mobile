import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/reports/domain/models/jpeg.dart';

import '../../../../support/sample_images.dart';

/// Os segmentos do JPEG, na ordem, para conferir o que ficou e o que saiu.
List<int> _markers(Uint8List bytes) {
  final markers = <int>[];
  var offset = 2;
  while (offset + 4 <= bytes.length) {
    final marker = bytes[offset + 1];
    markers.add(marker);
    if (marker == 0xda) break;
    offset += 2 + ((bytes[offset + 2] << 8) | bytes[offset + 3]);
  }
  return markers;
}

void main() {
  group('hasJpegSignature', () {
    test('deve aceitar o JPEG, com o início e o fim', () {
      expect(hasJpegSignature(samplePhotoJpeg), isTrue);
      expect(hasJpegSignature(syntheticJpeg(width: 1, height: 1)), isTrue);
    });

    test('deve recusar o PNG, o JPEG cortado e os bytes curtos', () {
      expect(hasJpegSignature(samplePng), isFalse);
      expect(
        hasJpegSignature(Uint8List.sublistView(samplePhotoJpeg, 0, samplePhotoJpeg.length - 1)),
        isFalse,
      );
      expect(hasJpegSignature(Uint8List.fromList([0xff, 0xd8, 0xff])), isFalse);
      expect(hasJpegSignature(Uint8List(0)), isFalse);
    });
  });

  group('parseJpeg', () {
    test('deve ler as dimensões do quadro', () {
      expect(
        parseJpeg(samplePhotoJpeg),
        isA<JpegImage>().having((jpeg) => jpeg.width, 'width', 160),
      );
      expect(parseJpeg(samplePhotoJpeg)!.height, 120);
      expect(parseJpeg(syntheticJpeg(width: 2048, height: 1536))!.width, 2048);
    });

    test('deve manter a imagem sem metadados como está', () {
      final jpeg = parseJpeg(samplePhotoJpeg)!;

      expect(jpeg.bytes, samplePhotoJpeg);
    });

    test('deve tirar o EXIF da foto da câmera e manter o resto (RM22)', () {
      expect(_markers(sampleJpegWithExif), contains(0xe1));

      final jpeg = parseJpeg(sampleJpegWithExif)!;

      expect(_markers(jpeg.bytes), isNot(contains(0xe1)));
      expect(_markers(jpeg.bytes), contains(0xc0));
      expect(jpeg.bytes.length, lessThan(sampleJpegWithExif.length));
      expect(String.fromCharCodes(jpeg.bytes), isNot(contains('Modelo do aparelho')));
      expect(parseJpeg(jpeg.bytes), jpeg, reason: 'Sem o EXIF, a imagem continua um JPEG.');
      expect((jpeg.width, jpeg.height), (32, 24));
    });

    test('deve tirar o APP1 de um JPEG sintético', () {
      final jpeg = parseJpeg(syntheticJpeg(width: 10, height: 10, withExif: true))!;

      expect(jpeg.bytes, syntheticJpeg(width: 10, height: 10));
    });

    test('deve recusar o que não é um JPEG', () {
      final noFrame = Uint8List.fromList([0xff, 0xd8, 0xff, 0xda, 0x00, 0x02, 0x00, 0xff, 0xd9]);
      final zeroWidth = syntheticJpeg(width: 0, height: 10);
      final brokenLength = Uint8List.fromList([0xff, 0xd8, 0xff, 0xc0, 0x7f, 0xff, 0xff, 0xd9]);
      final secondStart = Uint8List.fromList([0xff, 0xd8, 0xff, 0xd8, 0x00, 0xff, 0xd9]);

      for (final bytes in [samplePng, noFrame, zeroWidth, brokenLength, secondStart]) {
        expect(parseJpeg(bytes), isNull, reason: '$bytes');
      }
    });

    test('não deve mostrar os bytes no texto', () {
      expect(
        parseJpeg(samplePhotoJpeg).toString(),
        'JpegImage(160x120, ${samplePhotoJpeg.length} bytes)',
      );
    });
  });
}
