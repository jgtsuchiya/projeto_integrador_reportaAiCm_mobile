import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/core/media/flutter_image_compressor.dart';
import 'package:reportaai_cm/core/media/image_compressor.dart';

/// O tratamento das imagens. Os testes o trocam pelo `FakeImageCompressor` com
/// `imageCompressorProvider.overrideWithValue(...)`.
final imageCompressorProvider = Provider<ImageCompressor>((ref) => FlutterImageCompressor());
