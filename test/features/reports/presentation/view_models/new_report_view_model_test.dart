import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/core/location/location_service.dart';
import 'package:reportaai_cm/core/media/image_compressor.dart';
import 'package:reportaai_cm/core/media/photo_capture.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/reports/domain/models/geo_location.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_description.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/my_reports_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/new_report_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_location.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_photo_preparation.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_location_service.dart';
import '../../../../support/fake_profile_repository.dart';
import '../../../../support/fake_report_repository.dart';
import '../../../../support/report_fakes.dart';
import '../../../../support/sample_images.dart';

/// O formato do UUID v4 da `Idempotency-Key`.
final _uuidV4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

void main() {
  group('NewReportViewModel', () {
    late AuthFakes auth;
    late ReportFakes reports;
    late ProviderContainer container;

    /// Monta o container com o Client dentro: [auth] com o e-mail confirmado, se o teste não
    /// trocar antes.
    Future<void> setUpContainer() async {
      container = ProviderContainer.test(
        overrides: [...auth.overrides, ...reports.overrides],
        retry: noAutomaticRetry,
      )..listen(authControllerProvider, (_, _) {});
      await pumpEventQueue();
    }

    setUp(() async {
      auth = verifiedAuthFakes();
      reports = ReportFakes();
      await setUpContainer();
    });

    /// Abre a tela: a câmera abre, e o teste espera a foto e a localização.
    Future<void> open() async {
      container.listen(newReportViewModelProvider, (_, _) {});
      await pumpEventQueue();
    }

    NewReportViewModel sut() => container.read(newReportViewModelProvider.notifier);
    NewReportState state() => container.read(newReportViewModelProvider);

    group('foto e localização', () {
      test(
        'deve abrir a câmera, tratar a foto e ler a localização ao abrir (RM21 e RM22)',
        () async {
          await open();

          expect(reports.camera.calls, 1);
          expect(reports.compressor.calls, hasLength(2));
          expect(reports.location.positionCalls, 1);
          expect(state().photoStatus, PhotoStatus.ready);
          expect(state().photo?.photo, samplePhotoJpeg);
          expect(state().location.status, LocationStatus.ready);
          expect(state().nearby, isEmpty);
          expect(state().canSubmit, isTrue);
        },
      );

      test('deve reaproveitar a foto que o Android não entregou, sem abrir a câmera', () async {
        reports.camera.lostPhoto = sampleJpegWithExif;

        await open();

        expect(reports.camera.calls, 0);
        expect(reports.camera.lostPhotoCalls, 1);
        expect(state().photoStatus, PhotoStatus.ready);
      });

      test('não deve abrir a câmera sem o e-mail confirmado e deve abrir com a confirmação '
          '(RM20)', () async {
        auth = AuthFakes(signedIn: true);
        await setUpContainer();

        await open();

        expect(reports.camera.calls, 0);

        auth.profile.result = clientProfileWith(emailVerifiedAt: emailVerifiedAt);
        await container.read(authControllerProvider.notifier).refreshProfile();
        await pumpEventQueue();

        expect(reports.camera.calls, 1);
        expect(state().photoStatus, PhotoStatus.ready);
      });

      test('deve ficar sem foto quando o cidadão cancela a câmera', () async {
        reports.camera.photo = null;

        await open();

        expect(state().photoStatus, PhotoStatus.empty);
        expect(state().location.status, LocationStatus.idle);
        expect(state().canSubmit, isFalse);
        expect(state().hasUnsentPhoto, isFalse);
      });

      test('deve manter a foto anterior quando o cidadão cancela o "Tirar outra"', () async {
        await open();
        final photo = state().photo;
        reports.camera.photo = null;

        await sut().takePhoto();

        expect(state().photoStatus, PhotoStatus.ready);
        expect(state().photo, same(photo));
        expect(reports.location.positionCalls, 1);
      });

      test('deve refazer a foto e a localização no "Tirar outra"', () async {
        await open();

        await sut().takePhoto();

        expect(reports.camera.calls, 2);
        expect(reports.location.positionCalls, 2);
        expect(reports.repository.nearbyCalls, hasLength(2));
      });

      test('deve mostrar o carregando enquanto a foto é tratada', () async {
        reports.compressor.pending = Completer();

        await open();

        expect(state().photoStatus, PhotoStatus.processing);
        expect(state().hasUnsentPhoto, isTrue);
        expect(state().canSubmit, isFalse);

        reports.compressor.pending!.complete();
        await pumpEventQueue();

        expect(state().photoStatus, PhotoStatus.ready);
      });

      test('deve avisar a câmera que não abre e a câmera negada', () async {
        reports.camera.error = const CameraUnavailableException();
        await open();

        expect(state().photoStatus, PhotoStatus.failed);
        expect(state().photoError, NewReportViewModel.cameraUnavailableMessage);

        reports.camera.error = const CameraPermissionDeniedException();
        await sut().takePhoto();

        expect(state().photoError, NewReportViewModel.cameraDeniedMessage);
        expect(state().canSubmit, isFalse);
      });

      test('deve pedir outra foto quando o tratamento falha', () async {
        reports.compressor.error = const ImageCompressionException();

        await open();

        expect(state().photoStatus, PhotoStatus.failed);
        expect(state().photoError, photoNotUsableMessage);
      });

      test('deve bloquear o envio com a localização imprecisa ou simulada e liberar no '
          '"Atualizar localização" (RM21)', () async {
        reports.location.position = campoMouraoPositionWith(accuracyMeters: 80);
        await open();

        expect(state().location.status, LocationStatus.inaccurate);
        expect(state().canSubmit, isFalse);
        expect(reports.repository.nearbyCalls, isEmpty);

        reports.location.position = campoMouraoPositionWith(isMocked: true);
        await sut().refreshLocation();

        expect(state().location.status, LocationStatus.mocked);
        expect(state().canSubmit, isFalse);

        reports.location.position = campoMouraoPosition;
        await sut().refreshLocation();

        expect(state().location.status, LocationStatus.ready);
        expect(state().canSubmit, isTrue);
      });

      test('deve pedir a permissão só depois da explicação, e ler a posição com ela', () async {
        reports.location.permission = LocationPermissionStatus.denied;
        await open();

        expect(state().location.status, LocationStatus.permissionNeeded);
        expect(reports.location.requestPermissionCalls, 0);

        await sut().requestLocationPermission();

        expect(reports.location.requestPermissionCalls, 1);
        expect(state().location.status, LocationStatus.ready);
      });

      test('deve ler a localização de novo na volta das configurações', () async {
        reports.location.permission = LocationPermissionStatus.deniedForever;
        await open();

        await sut().openAppSettings();
        reports.location.permission = LocationPermissionStatus.granted;
        await sut().onResume();

        expect(reports.location.openAppSettingsCalls, 1);
        expect(state().location.status, LocationStatus.ready);
      });

      test('deve abrir as configurações da localização com o GPS desligado', () async {
        reports.location.serviceEnabled = false;
        await open();

        expect(state().location.status, LocationStatus.serviceDisabled);

        await sut().openLocationSettings();

        expect(reports.location.openLocationSettingsCalls, 1);
      });

      test('não deve ler a localização de novo na volta com ela já pronta', () async {
        await open();

        await sut().onResume();

        expect(reports.location.positionCalls, 1);
      });
    });

    group('reporte repetido (RM23)', () {
      test('deve buscar os reportes a até 30 m e bloquear o envio até a resposta', () async {
        reports.repository.nearby = [othersReport()];

        await open();

        expect(reports.repository.nearbyCalls, [
          (point: const GeoPoint(latitude: -24.045812, longitude: -52.378901), radiusMeters: 30),
        ]);
        expect(state().duplicate, othersReport());
        expect(state().canSubmit, isFalse);
      });

      test('deve seguir com o reporte novo no "É outro buraco"', () async {
        reports.repository.nearby = [othersReport()];
        await open();

        sut().dismissDuplicate();

        expect(state().duplicate, isNull);
        expect(state().canSubmit, isTrue);
      });

      test('não deve avisar o reporte a mais de 30 m', () async {
        reports.repository.nearby = [othersReport(distanceMeters: 45)];

        await open();

        expect(state().duplicate, isNull);
      });

      test('deve liberar o envio quando a busca falha', () async {
        reports.repository.nearbyError = const NetworkException();

        await open();

        expect(state().nearby, isEmpty);
        expect(state().canSubmit, isTrue);
      });

      test('deve esperar a busca antes de liberar o envio', () async {
        reports.repository.nearbyPending = Completer();

        await open();

        expect(state().isCheckingNearby, isTrue);
        expect(state().canSubmit, isFalse);

        reports.repository.nearbyPending!.complete();
        await pumpEventQueue();

        expect(state().canSubmit, isTrue);
      });
    });

    group('envio', () {
      test('deve enviar a foto, a localização e a descrição sem os espaços das pontas', () async {
        await open();

        final report = await sut().submit('  Perto do semáforo  ');

        final call = reports.repository.createCalls.single;
        expect(report, reports.repository.mine.first);
        expect(call.draft.description, 'Perto do semáforo');
        expect(call.draft.photo, state().photo);
        expect(
          call.draft.location,
          const GeoLocation(latitude: -24.045812, longitude: -52.378901, accuracyMeters: 8),
        );
        expect(call.idempotencyKey, matches(_uuidV4));
      });

      test('deve enviar sem descrição quando o campo está vazio', () async {
        await open();

        await sut().submit('   ');

        expect(reports.repository.createCalls.single.draft.description, isNull);
      });

      test('deve repetir depois do timeout com a mesma Idempotency-Key (RM24)', () async {
        await open();
        reports.repository.createError = const NetworkException(isTimeout: true);

        expect(await sut().submit('Buraco'), isNull);

        expect(state().message, NewReportViewModel.sendFailedMessage);
        expect(state().canRetry, isTrue);
        expect(state().photo, isNotNull, reason: 'Os dados continuam na tela.');

        reports.repository.createError = null;
        final report = await sut().submit('Buraco');

        final keys = [for (final call in reports.repository.createCalls) call.idempotencyKey];
        expect(report, isNotNull);
        expect(keys, hasLength(2));
        expect(keys.toSet(), {sut().idempotencyKey});
      });

      test('deve usar a mesma chave em toda a tela, também depois do "Tirar outra"', () async {
        await open();
        reports.repository.createError = const ServerException(statusCode: 503);
        await sut().submit('');
        await sut().takePhoto();
        reports.repository.createError = null;

        await sut().submit('');

        expect(
          reports.repository.createCalls.map((call) => call.idempotencyKey).toSet(),
          hasLength(1),
        );
      });

      test('não deve enviar duas vezes', () async {
        await open();
        reports.repository.createPending = Completer();

        unawaited(sut().submit(''));
        await pumpEventQueue();
        final second = await sut().submit('');

        expect(second, isNull);
        expect(state().isSubmitting, isTrue);
        expect(reports.repository.createCalls, hasLength(1));
        reports.repository.createPending!.complete();
      });

      test('deve recusar a descrição longa antes de enviar', () async {
        await open();

        expect(await sut().submit('a' * 501), isNull);

        expect(state().descriptionError, descriptionTooLongMessage);
        expect(reports.repository.createCalls, isEmpty);

        sut().descriptionChanged();

        expect(state().descriptionError, isNull);
      });

      test('deve atualizar "Meus reportes" depois do envio', () async {
        container.listen(myReportsViewModelProvider, (_, _) {});
        await open();
        expect(reports.repository.listMineCalls, hasLength(1));

        await sut().submit('');
        await pumpEventQueue();

        expect(reports.repository.listMineCalls, hasLength(2));
      });

      for (final (description, error) in [
        (
          'o 400 da foto',
          const ValidationException(
            fieldErrors: [FieldError(field: 'photo.content', message: 'A foto passa de 2 MB.')],
          ),
        ),
        ('o 413', const ServerException(statusCode: 413)),
      ]) {
        test('deve pedir outra foto com $description', () async {
          await open();
          reports.repository.createError = error;

          await sut().submit('');

          expect(state().photoStatus, PhotoStatus.failed);
          expect(state().photoError, photoNotUsableMessage);
          expect(state().photo, isNull);
          expect(state().canSubmit, isFalse);
        });
      }

      test('deve mostrar o 400 da descrição embaixo do campo', () async {
        await open();
        reports.repository.createError = const ValidationException(
          fieldErrors: [FieldError(field: 'description', message: 'Descrição inválida.')],
        );

        await sut().submit('Buraco');

        expect(state().descriptionError, 'Descrição inválida.');
        expect(state().message, isNull);
      });

      test('deve mostrar o 400 de outro campo como aviso geral', () async {
        await open();
        reports.repository.createError = const ValidationException(
          fieldErrors: [
            FieldError(
              field: 'location.latitude',
              message: 'A latitude deve estar entre -90 e 90.',
            ),
          ],
        );

        await sut().submit('');

        expect(state().message, 'A latitude deve estar entre -90 e 90.');
      });

      test('deve mostrar a message do 422 da API, sem "Tentar de novo"', () async {
        await open();
        reports.repository.createError = const BusinessRuleException(
          message: 'Você chegou ao limite de 10 reportes por dia.',
        );

        await sut().submit('');

        expect(state().message, 'Você chegou ao limite de 10 reportes por dia.');
        expect(state().canRetry, isFalse);
        expect(state().isSubmitting, isFalse);
      });

      test('deve mostrar a mensagem de outro erro da API', () async {
        await open();
        reports.repository.createError = const ForbiddenException();

        await sut().submit('');

        expect(state().message, ForbiddenException.defaultMessage);
      });
    });

    test('não deve mostrar a foto nem as coordenadas no texto do estado (RM27)', () async {
      await open();

      final text = state().toString();

      expect(text, isNot(contains('24.04')));
      expect(text, contains('photo: ready'));
      expect(state(), state());
      expect(state().hashCode, state().hashCode);
    });
  });
}
