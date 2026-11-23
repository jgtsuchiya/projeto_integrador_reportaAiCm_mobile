import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/reports/domain/models/prepared_photo.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_limits.dart';

import '../../../../support/sample_images.dart';

Matcher _invalid(ReportImageKind kind, ReportImageProblem problem, String message) => throwsA(
  isA<InvalidReportPhotoException>()
      .having((error) => error.kind, 'kind', kind)
      .having((error) => error.problem, 'problem', problem)
      .having((error) => error.message, 'message', message),
);

void main() {
  group('PreparedPhoto', () {
    test('deve aceitar a foto e a miniatura e ler as dimensões da foto', () {
      final sut = PreparedPhoto.create(photo: samplePhotoJpeg, thumbnail: sampleThumbnailJpeg);

      expect(sut.photo, samplePhotoJpeg);
      expect(sut.thumbnail, sampleThumbnailJpeg);
      expect((sut.width, sut.height), (160, 120));
    });

    test('deve tirar o EXIF que sobrou nas duas imagens (RM22)', () {
      final withExif = syntheticJpeg(width: 10, height: 8, withExif: true);

      final sut = PreparedPhoto.create(photo: withExif, thumbnail: withExif);

      expect(sut.photo, syntheticJpeg(width: 10, height: 8));
      expect(sut.thumbnail, syntheticJpeg(width: 10, height: 8));
    });

    test('deve recusar a imagem que não é JPEG, com a mensagem da API', () {
      expect(
        () => PreparedPhoto.create(photo: samplePng, thumbnail: sampleThumbnailJpeg),
        _invalid(
          ReportImageKind.photo,
          ReportImageProblem.notJpeg,
          'A foto precisa ser uma imagem JPEG.',
        ),
      );
      expect(
        () => PreparedPhoto.create(photo: samplePhotoJpeg, thumbnail: samplePng),
        _invalid(
          ReportImageKind.thumbnail,
          ReportImageProblem.notJpeg,
          'A miniatura precisa ser uma imagem JPEG.',
        ),
      );
    });

    test('deve aceitar a foto de exatamente 2 MB e recusar 1 byte a mais (RN29)', () {
      final atLimit = syntheticJpeg(width: 1600, height: 1200, length: ReportLimits.photoMaxBytes);
      final overLimit = syntheticJpeg(
        width: 1600,
        height: 1200,
        length: ReportLimits.photoMaxBytes + 1,
      );

      expect(
        PreparedPhoto.create(photo: atLimit, thumbnail: sampleThumbnailJpeg).photo.length,
        2097152,
      );
      expect(
        () => PreparedPhoto.create(photo: overLimit, thumbnail: sampleThumbnailJpeg),
        _invalid(ReportImageKind.photo, ReportImageProblem.tooHeavy, 'A foto passa de 2 MB.'),
      );
    });

    test('deve aceitar a miniatura de exatamente 100 KB e recusar 1 byte a mais', () {
      final atLimit = syntheticJpeg(
        width: 400,
        height: 300,
        length: ReportLimits.thumbnailMaxBytes,
      );
      final overLimit = syntheticJpeg(
        width: 400,
        height: 300,
        length: ReportLimits.thumbnailMaxBytes + 1,
      );

      expect(
        PreparedPhoto.create(photo: samplePhotoJpeg, thumbnail: atLimit).thumbnail.length,
        102400,
      );
      expect(
        () => PreparedPhoto.create(photo: samplePhotoJpeg, thumbnail: overLimit),
        _invalid(
          ReportImageKind.thumbnail,
          ReportImageProblem.tooHeavy,
          'A miniatura passa de 100 KB.',
        ),
      );
    });

    test('deve aceitar o maior lado no limite e recusar 1 px a mais, na foto e na miniatura', () {
      expect(
        PreparedPhoto.create(
          photo: syntheticJpeg(width: 1536, height: 2048),
          thumbnail: syntheticJpeg(width: 480, height: 360),
        ).height,
        2048,
      );
      expect(
        () => PreparedPhoto.create(
          photo: syntheticJpeg(width: 1536, height: 2049),
          thumbnail: sampleThumbnailJpeg,
        ),
        _invalid(
          ReportImageKind.photo,
          ReportImageProblem.tooLarge,
          'A foto passa de 2048 px no maior lado.',
        ),
      );
      expect(
        () => PreparedPhoto.create(
          photo: samplePhotoJpeg,
          thumbnail: syntheticJpeg(width: 481, height: 360),
        ),
        _invalid(
          ReportImageKind.thumbnail,
          ReportImageProblem.tooLarge,
          'A miniatura passa de 480 px no maior lado.',
        ),
      );
    });

    test('deve conferir o formato antes do tamanho, como a API', () {
      final heavyPng = syntheticJpeg(width: 1, height: 1, length: ReportLimits.photoMaxBytes + 10)
        ..[0] = 0x89;

      expect(
        () => PreparedPhoto.create(photo: heavyPng, thumbnail: sampleThumbnailJpeg),
        _invalid(
          ReportImageKind.photo,
          ReportImageProblem.notJpeg,
          'A foto precisa ser uma imagem JPEG.',
        ),
      );
    });

    test('não deve mostrar os bytes no texto (RM27)', () {
      final sut = PreparedPhoto.create(photo: samplePhotoJpeg, thumbnail: sampleThumbnailJpeg);

      expect(
        sut.toString(),
        'PreparedPhoto(160x120, foto com ${samplePhotoJpeg.length} bytes, miniatura com '
        '${sampleThumbnailJpeg.length} bytes)',
      );
    });

    test('deve comparar pela identidade das imagens, sem percorrer os bytes', () {
      final sut = PreparedPhoto.create(photo: samplePhotoJpeg, thumbnail: sampleThumbnailJpeg);

      expect(sut, sut);
      expect(sut.hashCode, sut.hashCode);
      expect(
        sut,
        isNot(PreparedPhoto.create(photo: samplePhotoJpeg, thumbnail: sampleThumbnailJpeg)),
      );
    });
  });
}
