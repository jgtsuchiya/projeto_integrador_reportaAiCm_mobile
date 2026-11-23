import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/core/config/app_config_provider.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/reports/data/repositories/api_report_repository.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_draft.dart';
import 'package:reportaai_cm/features/reports/reports_providers.dart';

import '../../support/fake_report_repository.dart';
import '../../support/pump_app.dart';
import '../../support/sample_images.dart';

void main() {
  group('reportRepositoryProvider', () {
    test('deve fornecer a implementação que chama a API', () {
      final container = ProviderContainer.test(
        overrides: [appConfigProvider.overrideWithValue(testConfig)],
      );

      expect(container.read(reportRepositoryProvider), isA<ApiReportRepository>());
    });
  });

  group('reportPhotoProvider', () {
    late FakeReportRepository repository;
    late ProviderContainer container;

    final thumbnailKey = reportPhotoKey(
      sampleReport.id,
      sampleReport.photo,
      ReportPhotoSize.thumbnail,
    );

    setUp(() {
      repository = FakeReportRepository()..mine = [sampleReport];
      container = ProviderContainer.test(
        overrides: [reportRepositoryProvider.overrideWithValue(repository)],
        retry: noAutomaticRetry,
      );
    });

    test('deve buscar a imagem uma vez para as telas que a mostram juntas', () async {
      final first = container.listen(reportPhotoProvider(thumbnailKey), (_, _) {});
      final second = container.listen(reportPhotoProvider(thumbnailKey), (_, _) {});

      expect(await container.read(reportPhotoProvider(thumbnailKey).future), sampleThumbnailJpeg);
      expect(repository.photoCalls, [(reportId: sampleReport.id, size: ReportPhotoSize.thumbnail)]);
      first.close();
      second.close();
    });

    test('deve guardar a imagem por alguns minutos depois de sair da tela', () async {
      final screen = container.listen(reportPhotoProvider(thumbnailKey), (_, _) {});
      await container.read(reportPhotoProvider(thumbnailKey).future);
      screen.close();
      await pumpEventQueue();

      final again = container.listen(reportPhotoProvider(thumbnailKey), (_, _) {});
      await container.read(reportPhotoProvider(thumbnailKey).future);

      expect(repository.photoCalls, hasLength(1));
      again.close();
    });

    test('deve buscar de novo depois do tempo do cache', () {
      fakeAsync((async) {
        final screen = container.listen(reportPhotoProvider(thumbnailKey), (_, _) {});
        async.flushMicrotasks();
        screen.close();
        async
          ..elapse(reportPhotoCacheDuration)
          ..flushMicrotasks();

        container.listen(reportPhotoProvider(thumbnailKey), (_, _) {});
        async.flushMicrotasks();

        expect(repository.photoCalls, hasLength(2));
      });
    });

    test('deve buscar a foto nova quando o id dela muda, sem mostrar a antiga', () async {
      final newPhotoKey = (
        reportId: sampleReport.id,
        photoId: 'foto-nova',
        size: ReportPhotoSize.thumbnail,
      );
      container
        ..listen(reportPhotoProvider(thumbnailKey), (_, _) {})
        ..listen(reportPhotoProvider(newPhotoKey), (_, _) {});

      await container.read(reportPhotoProvider(thumbnailKey).future);
      await container.read(reportPhotoProvider(newPhotoKey).future);

      expect(repository.photoCalls, hasLength(2));
    });

    test('não deve guardar a imagem que falhou', () async {
      repository.photoError = const NetworkException();
      final screen = container.listen(reportPhotoProvider(thumbnailKey), (_, _) {});
      await expectLater(
        container.read(reportPhotoProvider(thumbnailKey).future),
        throwsA(isA<NetworkException>()),
      );
      screen.close();
      await pumpEventQueue();

      repository.photoError = null;
      container.listen(reportPhotoProvider(thumbnailKey), (_, _) {});

      expect(await container.read(reportPhotoProvider(thumbnailKey).future), sampleThumbnailJpeg);
      expect(repository.photoCalls, hasLength(2));
    });
  });
}
