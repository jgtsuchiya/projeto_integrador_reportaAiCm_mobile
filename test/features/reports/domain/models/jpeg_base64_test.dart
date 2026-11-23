import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/reports/domain/models/jpeg_base64.dart';

import '../../../../support/sample_images.dart';

void main() {
  group('encodeJpegBase64 e decodeJpegBase64', () {
    test('deve voltar aos mesmos bytes', () {
      final text = encodeJpegBase64(samplePhotoJpeg);

      expect(decodeJpegBase64(text), samplePhotoJpeg);
    });

    test('deve gerar o base64 padrão, com o = do fim e sem o prefixo data:', () {
      final text = encodeJpegBase64(sampleThumbnailJpeg);

      expect(text, base64Encode(sampleThumbnailJpeg));
      expect(text, startsWith('/9j/'));
      expect(text, isNot(contains('\n')));
      expect(text.length % 4, 0);
    });

    test('deve recusar codificar o que não é JPEG', () {
      expect(() => encodeJpegBase64(samplePng), throwsArgumentError);
    });

    test('deve recusar o PNG em base64', () {
      expect(
        () => decodeJpegBase64(base64Encode(samplePng)),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'A imagem não é um JPEG.',
          ),
        ),
      );
    });

    test('deve recusar o texto que não é base64 no formato da API', () {
      final valid = base64Encode(samplePhotoJpeg);
      final invalid = [
        'data:image/jpeg;base64,$valid',
        valid.substring(0, valid.length - 1),
        '${valid.substring(0, 8)}\n${valid.substring(8)}',
        valid.replaceAll('+', '-').replaceAll('/', '_'),
        'não é base64',
      ];

      for (final text in invalid) {
        expect(() => decodeJpegBase64(text), throwsFormatException, reason: text);
      }
    });

    test('não deve mostrar o texto na mensagem do erro (RM27)', () {
      const text = 'AAAA====';

      expect(
        () => decodeJpegBase64(text),
        throwsA(isA<FormatException>().having((error) => '$error', 'texto', isNot(contains(text)))),
      );
    });

    test('deve ler o JPEG vazio de dados como os bytes', () {
      final jpeg = syntheticJpeg(width: 2, height: 2);

      expect(decodeJpegBase64(base64Encode(jpeg)), Uint8List.fromList(jpeg));
    });
  });
}
