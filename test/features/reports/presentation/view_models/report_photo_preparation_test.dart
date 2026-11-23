import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/media/image_compressor.dart';
import 'package:reportaai_cm/features/reports/domain/models/prepared_photo.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_photo_preparation.dart';

import '../../../../support/fake_image_compressor.dart';
import '../../../../support/sample_images.dart';

void main() {
  group('prepareReportPhoto', () {
    late FakeImageCompressor compressor;

    setUp(() => compressor = FakeImageCompressor());

    test(
      'deve gerar a foto com 1600 px e a miniatura com 400 px, a partir da foto (RM22)',
      () async {
        final prepared = await prepareReportPhoto(compressor, sampleJpegWithExif);

        expect(compressor.calls, [
          (
            inputLength: sampleJpegWithExif.length,
            maxSide: 1600,
            quality: 80,
            maxBytes: 2097152,
            minQuality: 60,
          ),
          (
            inputLength: samplePhotoJpeg.length,
            maxSide: 400,
            quality: 70,
            maxBytes: 102400,
            minQuality: 50,
          ),
        ]);
        expect(prepared.photo, samplePhotoJpeg);
        expect(prepared.thumbnail, sampleThumbnailJpeg);
        expect((prepared.width, prepared.height), (160, 120));
      },
    );

    test('deve repassar a imagem que o aparelho não trata', () async {
      compressor.error = const ImageCompressionException();

      await expectLater(
        prepareReportPhoto(compressor, sampleJpegWithExif),
        throwsA(isA<ImageCompressionException>()),
      );
    });

    test('deve recusar o resultado fora das regras da API', () async {
      compressor.photo = samplePng;

      await expectLater(
        prepareReportPhoto(compressor, sampleJpegWithExif),
        throwsA(isA<InvalidReportPhotoException>()),
      );
    });
  });
}
