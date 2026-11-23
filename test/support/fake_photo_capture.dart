import 'dart:async';
import 'dart:typed_data';

import 'package:reportaai_cm/core/media/photo_capture.dart';

import 'sample_images.dart';

/// Fake do [PhotoCapture], escrito à mão como os fakes dos repositórios. A câmera devolve a
/// [photo] (a foto com o EXIF, como a câmera grava, se o teste não trocar), e cada teste confere
/// as chamadas feitas.
final class FakePhotoCapture implements PhotoCapture {
  /// A foto da próxima chamada. `null` é o cidadão que cancela a câmera.
  Uint8List? photo = sampleJpegWithExif;

  /// Lançado na próxima chamada, como a câmera que não abre.
  PhotoCaptureException? error;

  /// Enquanto não é completado, a câmera fica aberta.
  Completer<void>? pending;

  int calls = 0;

  /// A foto que o Android não entregou porque fechou o app com a câmera aberta.
  Uint8List? lostPhoto;

  int lostPhotoCalls = 0;

  @override
  Future<Uint8List?> takePhoto() async {
    calls++;

    final pending = this.pending;
    if (pending != null) await pending.future;

    final error = this.error;
    if (error != null) throw error;

    return photo;
  }

  @override
  Future<Uint8List?> retrieveLostPhoto() async {
    lostPhotoCalls++;

    final lost = lostPhoto;
    // Como no Android: a foto perdida é entregue uma vez só.
    lostPhoto = null;
    return lost;
  }
}
