import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:reportaai_cm/core/location/location_service.dart';
import 'package:reportaai_cm/core/location/location_service_provider.dart';
import 'package:reportaai_cm/core/media/image_compressor.dart';
import 'package:reportaai_cm/core/media/image_compressor_provider.dart';
import 'package:reportaai_cm/core/media/photo_capture.dart';
import 'package:reportaai_cm/core/media/photo_capture_provider.dart';

import '../fixtures/report_photo.dart';

/// Um ponto do centro de Campo Mourão, dentro da área da API (`REPORT_AREA_BOUNDS`), com a
/// precisão de 8 m.
const campoMouraoLatitude = -24.045812;
const campoMouraoLongitude = -52.378901;

/// A câmera, o GPS e o tratamento da foto dos testes de integração: a câmera devolve a foto de
/// exemplo, e o GPS, um ponto de Campo Mourão. A API, a sessão e o resto do app são de verdade.
///
/// No Android e no iOS, o tratamento da foto é o nativo, de verdade. No computador, onde o
/// `flutter_image_compress` não existe, a foto de exemplo vai como está (ela já cabe nos limites).
List<Override> deviceFakeOverrides() => [
  photoCaptureProvider.overrideWithValue(const _FixturePhotoCapture()),
  locationServiceProvider.overrideWithValue(const _CampoMouraoLocationService()),
  if (!_hasNativeImageCompression)
    imageCompressorProvider.overrideWithValue(const _PassThroughImageCompressor()),
];

bool get _hasNativeImageCompression =>
    defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

final class _FixturePhotoCapture implements PhotoCapture {
  const new();

  @override
  Future<Uint8List?> takePhoto() async => reportPhotoFixture;

  @override
  Future<Uint8List?> retrieveLostPhoto() async => null;
}

final class _CampoMouraoLocationService implements LocationService {
  const new();

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<LocationPermissionStatus> checkPermission() async => LocationPermissionStatus.granted;

  @override
  Future<LocationPermissionStatus> requestPermission() async => LocationPermissionStatus.granted;

  @override
  Future<DevicePosition> getCurrentPosition({
    Duration timeLimit = LocationService.defaultTimeLimit,
  }) async => DevicePosition(
    latitude: campoMouraoLatitude,
    longitude: campoMouraoLongitude,
    accuracyMeters: 8,
    isMocked: false,
    timestamp: DateTime.now(),
  );

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

/// Devolve a foto de exemplo como está: 480 x 360 px, já dentro dos limites da foto e da
/// miniatura.
final class _PassThroughImageCompressor implements ImageCompressor {
  const new();

  @override
  Future<CompressedImage> compressToFit(
    Uint8List bytes, {
    required int maxSide,
    required int quality,
    required int maxBytes,
    required int minQuality,
  }) async => CompressedImage(bytes: bytes, width: 480, height: 360, quality: quality);
}
