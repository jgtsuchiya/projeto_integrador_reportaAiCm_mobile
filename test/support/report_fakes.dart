import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:reportaai_cm/core/location/location_service_provider.dart';
import 'package:reportaai_cm/core/media/image_compressor_provider.dart';
import 'package:reportaai_cm/core/media/photo_capture_provider.dart';
import 'package:reportaai_cm/features/reports/reports_providers.dart';

import 'auth_fakes.dart';
import 'fake_image_compressor.dart';
import 'fake_location_service.dart';
import 'fake_photo_capture.dart';
import 'fake_profile_repository.dart';
import 'fake_report_repository.dart';

/// Os fakes dos reportes: o repositório, a câmera, o tratamento da foto e a localização. Os
/// [overrides] os colocam no `ProviderScope`, junto com os do [AuthFakes]:
///
/// ```dart
/// final auth = verifiedAuthFakes();
/// final reports = ReportFakes();
/// await tester.pumpWholeApp(overrides: [...auth.overrides, ...reports.overrides]);
/// ```
final class ReportFakes {
  final repository = FakeReportRepository();
  final camera = FakePhotoCapture();
  final compressor = FakeImageCompressor();
  final location = FakeLocationService();

  List<Override> get overrides => [
    reportRepositoryProvider.overrideWithValue(repository),
    photoCaptureProvider.overrideWithValue(camera),
    imageCompressorProvider.overrideWithValue(compressor),
    locationServiceProvider.overrideWithValue(location),
  ];
}

/// O [AuthFakes] com o Client dentro e o e-mail confirmado: quem abre e valida reportes (RM20).
AuthFakes verifiedAuthFakes() =>
    AuthFakes(signedIn: true)..profile.result = clientProfileWith(emailVerifiedAt: emailVerifiedAt);
