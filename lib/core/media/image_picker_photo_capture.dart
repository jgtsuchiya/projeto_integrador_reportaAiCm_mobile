import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reportaai_cm/core/media/photo_capture.dart';

/// [PhotoCapture] pelo pacote `image_picker`, que abre o app da câmera do aparelho. Os testes
/// passam um `ImagePicker` falso no `picker`.
///
/// A foto volta como o aparelho gravou: o tratamento (tamanho, qualidade, orientação e EXIF) é
/// do `ImageCompressor`, num passo só.
final class ImagePickerPhotoCapture implements PhotoCapture {
  new({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Uint8List?> takePhoto() async {
    if (!_picker.supportsImageSource(ImageSource.camera)) {
      throw const CameraUnavailableException();
    }

    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: ImageSource.camera,
        // Sem os metadados no iOS: o app tira o EXIF de qualquer jeito, e a leitura completa
        // pediria a permissão da galeria.
        requestFullMetadata: false,
      );
    } on PlatformException catch (error) {
      // `camera_access_denied`: o cidadão negou a câmera (o iOS pede a permissão).
      if (error.code == 'camera_access_denied') throw const CameraPermissionDeniedException();
      throw CameraUnavailableException(error);
    }

    return file == null ? null : await file.readAsBytes();
  }

  @override
  Future<Uint8List?> retrieveLostPhoto() async {
    // Só o Android implementa: no iOS, o app não é fechado com a câmera aberta.
    if (defaultTargetPlatform != TargetPlatform.android) return null;

    final response = await _picker.retrieveLostData();
    final file = response.file;
    if (response.isEmpty || file == null || response.type != RetrieveType.image) return null;

    return await file.readAsBytes();
  }
}
