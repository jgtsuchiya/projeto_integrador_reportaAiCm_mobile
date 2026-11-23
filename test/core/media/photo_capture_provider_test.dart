import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/media/image_picker_photo_capture.dart';
import 'package:reportaai_cm/core/media/photo_capture_provider.dart';

void main() {
  group('photoCaptureProvider', () {
    test('deve fornecer a implementação pelo image_picker', () {
      final container = ProviderContainer.test();

      expect(container.read(photoCaptureProvider), isA<ImagePickerPhotoCapture>());
    });
  });
}
