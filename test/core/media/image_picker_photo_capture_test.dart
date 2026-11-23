import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reportaai_cm/core/media/image_picker_photo_capture.dart';
import 'package:reportaai_cm/core/media/photo_capture.dart';

import '../../support/sample_images.dart';

/// O `image_picker` no lugar do aparelho: o teste define as respostas e confere os pedidos.
final class _FakeImagePicker extends Fake implements ImagePicker {
  bool supportsCamera = true;
  XFile? file;
  PlatformException? error;
  LostDataResponse lostData = LostDataResponse.empty();
  final sources = <ImageSource>[];
  final cameraDevices = <CameraDevice>[];
  final fullMetadata = <bool>[];
  int lostDataCalls = 0;

  @override
  bool supportsImageSource(ImageSource source) => source != ImageSource.camera || supportsCamera;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    sources.add(source);
    cameraDevices.add(preferredCameraDevice);
    fullMetadata.add(requestFullMetadata);
    if (error case final error?) throw error;

    return file;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async {
    lostDataCalls++;
    return lostData;
  }
}

void main() {
  group('ImagePickerPhotoCapture', () {
    late _FakeImagePicker picker;
    late ImagePickerPhotoCapture sut;

    setUp(() {
      picker = _FakeImagePicker();
      sut = ImagePickerPhotoCapture(picker: picker);
    });

    test('deve abrir só a câmera traseira e devolver os bytes da foto (RM21)', () async {
      picker.file = XFile.fromData(sampleJpegWithExif, mimeType: 'image/jpeg');

      final photo = await sut.takePhoto();

      expect(photo, sampleJpegWithExif);
      expect(picker.sources, [ImageSource.camera]);
      expect(picker.cameraDevices, [CameraDevice.rear]);
      expect(picker.fullMetadata, [false]);
    });

    test('deve devolver null quando o cidadão cancela a câmera', () async {
      expect(await sut.takePhoto(), isNull);
    });

    test('deve recusar o aparelho sem a câmera, sem abrir nada', () async {
      picker.supportsCamera = false;

      await expectLater(sut.takePhoto(), throwsA(isA<CameraUnavailableException>()));
      expect(picker.sources, isEmpty);
    });

    test('deve converter a câmera negada e os outros erros do sistema', () async {
      picker.error = PlatformException(code: 'camera_access_denied');

      await expectLater(sut.takePhoto(), throwsA(isA<CameraPermissionDeniedException>()));

      picker.error = PlatformException(code: 'no_available_camera');

      await expectLater(
        sut.takePhoto(),
        throwsA(
          isA<CameraUnavailableException>().having(
            (error) => error.cause,
            'cause',
            isA<PlatformException>(),
          ),
        ),
      );
    });

    group('no Android', () {
      setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
      tearDown(() => debugDefaultTargetPlatformOverride = null);

      test('deve recuperar a foto que o Android não entregou', () async {
        picker.lostData = LostDataResponse(
          file: XFile.fromData(sampleJpegWithExif),
          type: RetrieveType.image,
        );

        expect(await sut.retrieveLostPhoto(), sampleJpegWithExif);
      });

      test('deve devolver null sem foto perdida, ou com um vídeo', () async {
        expect(await sut.retrieveLostPhoto(), isNull);

        picker.lostData = LostDataResponse(
          file: XFile.fromData(Uint8List(4)),
          type: RetrieveType.video,
        );

        expect(await sut.retrieveLostPhoto(), isNull);
      });
    });

    test('não deve procurar a foto perdida fora do Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(await sut.retrieveLostPhoto(), isNull);
      expect(picker.lostDataCalls, 0);
    });
  });
}
