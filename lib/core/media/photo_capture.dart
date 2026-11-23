import 'dart:typed_data';

/// A foto não pôde ser tirada.
sealed class PhotoCaptureException implements Exception {
  const new();
}

/// O aparelho não tem câmera, ou o sistema não abre a câmera por este app (como no computador).
final class CameraUnavailableException extends PhotoCaptureException {
  const new([this.cause]);

  final Object? cause;
}

/// O cidadão negou o acesso à câmera (só o iOS pede a permissão: no Android, o app da câmera
/// do aparelho tira a foto).
final class CameraPermissionDeniedException extends PhotoCaptureException {
  const new();
}

/// A câmera do aparelho, para a foto do reporte. Só o `core/media/` conhece o pacote da câmera, e
/// o resto do app depende deste contrato. Os testes usam o `FakePhotoCapture`.
///
/// A foto vem só da câmera, nunca da galeria: a foto e a localização são do mesmo momento (RM21).
abstract interface class PhotoCapture {
  /// Abre a câmera traseira e devolve os bytes da foto, como o aparelho gravou (com o EXIF e na
  /// resolução da câmera), ou `null` se o cidadão cancelar. Lança uma [PhotoCaptureException]
  /// quando a câmera não abre.
  Future<Uint8List?> takePhoto();

  /// A foto que o Android não entregou porque fechou o app com a câmera aberta (aparelhos com
  /// pouca memória), ou `null` se não houver. No iOS, sempre `null`.
  Future<Uint8List?> retrieveLostPhoto();
}
