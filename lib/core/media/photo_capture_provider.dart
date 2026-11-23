import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/core/media/image_picker_photo_capture.dart';
import 'package:reportaai_cm/core/media/photo_capture.dart';

/// A câmera do aparelho. Os testes a trocam pelo `FakePhotoCapture` com
/// `photoCaptureProvider.overrideWithValue(...)`.
final photoCaptureProvider = Provider<PhotoCapture>((ref) => ImagePickerPhotoCapture());
