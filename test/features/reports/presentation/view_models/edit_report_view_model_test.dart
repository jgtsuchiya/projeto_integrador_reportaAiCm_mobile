import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/core/media/image_compressor.dart';
import 'package:reportaai_cm/core/media/photo_capture.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_description.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_draft.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/edit_report_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/my_reports_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/new_report_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_detail_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_photo_preparation.dart';

import '../../../../support/fake_report_repository.dart';
import '../../../../support/report_fakes.dart';
import '../../../../support/sample_images.dart';

void main() {
  group('EditReportViewModel', () {
    late ReportFakes reports;
    late ProviderContainer container;

    final report = sampleReportWith(id: 'reporte-1', description: 'Buraco fundo', canEdit: true);
    final provider = editReportViewModelProvider('reporte-1');
    final detail = reportDetailViewModelProvider('reporte-1');

    setUp(() async {
      reports = ReportFakes()..repository.mine = [report];
      container = ProviderContainer.test(overrides: reports.overrides, retry: noAutomaticRetry)
        // O detalhe fica embaixo da edição, como na pilha das telas.
        ..listen(detail, (_, _) {})
        ..listen(provider, (_, _) {});
      await pumpEventQueue();
    });

    EditReportViewModel sut() => container.read(provider.notifier);
    EditReportState state() => container.read(provider);

    group('changesFrom', () {
      test('não deve mudar nada com a mesma descrição, mesmo com espaços nas pontas', () {
        expect(sut().changesFrom(report, '  Buraco fundo ').isEmpty, isTrue);
      });

      test('deve mandar a descrição nova sem os espaços, e a vazia para apagar', () {
        expect(
          sut().changesFrom(report, ' Bem fundo '),
          const ReportChanges(description: 'Bem fundo'),
        );
        expect(sut().changesFrom(report, '   '), const ReportChanges(description: ''));
      });

      test('não deve mudar a descrição que já não existia com o campo vazio', () {
        final withoutDescription = sampleReportWith(id: 'reporte-1', clearDescription: true);

        expect(sut().changesFrom(withoutDescription, '').isEmpty, isTrue);
      });
    });

    group('trocar a foto', () {
      test('deve tirar e tratar a foto nova, que entra nas mudanças', () async {
        await sut().takePhoto();

        expect(state().photoStatus, PhotoStatus.ready);
        expect(state().newPhoto?.photo, samplePhotoJpeg);
        expect(sut().changesFrom(report, 'Buraco fundo').photo, state().newPhoto);
      });

      test('deve manter a foto do reporte quando o cidadão cancela a câmera', () async {
        reports.camera.photo = null;

        await sut().takePhoto();

        expect(state(), const EditReportState());
      });

      test('deve avisar a câmera que não abre e a foto que não pôde ser usada', () async {
        reports.camera.error = const CameraPermissionDeniedException();
        await sut().takePhoto();

        expect(state().photoError, NewReportViewModel.cameraDeniedMessage);

        reports.camera.error = const CameraUnavailableException();
        await sut().takePhoto();

        expect(state().photoError, NewReportViewModel.cameraUnavailableMessage);

        reports.camera.error = null;
        reports.compressor.error = const ImageCompressionException();
        await sut().takePhoto();

        expect(state().photoStatus, PhotoStatus.failed);
        expect(state().photoError, photoNotUsableMessage);
      });

      test('deve esperar o tratamento antes de salvar', () async {
        reports.compressor.pending = Completer();

        unawaited(sut().takePhoto());
        await pumpEventQueue();

        expect(state().isChangingPhoto, isTrue);
        expect(await sut().submit(report, 'Nova'), isNull);
        expect(reports.repository.updateCalls, isEmpty);
        reports.compressor.pending!.complete();
      });
    });

    group('submit', () {
      test('deve salvar só a descrição, trocar o detalhe e atualizar a lista (RM25)', () async {
        container.listen(myReportsViewModelProvider, (_, _) {});
        await pumpEventQueue();

        final outcome = await sut().submit(report, 'Bem fundo');
        await pumpEventQueue();

        expect(outcome, const EditReportOutcome(EditReportViewModel.savedMessage));
        expect(
          reports.repository.updateCalls.single.changes,
          const ReportChanges(description: 'Bem fundo'),
        );
        expect(container.read(detail).report?.description, 'Bem fundo');
        expect(reports.repository.getByIdCalls, hasLength(1), reason: 'O detalhe veio do PATCH.');
        expect(reports.repository.listMineCalls, hasLength(2));
      });

      test('deve salvar só a foto, que volta com outro id', () async {
        await sut().takePhoto();

        await sut().submit(report, 'Buraco fundo');

        final changes = reports.repository.updateCalls.single.changes;
        expect(changes.description, isNull);
        expect(changes.photo, isNotNull);
        expect(container.read(detail).report?.photo.id, '${report.photo.id}-nova');
      });

      test('não deve chamar a API sem mudança', () async {
        expect(await sut().submit(report, 'Buraco fundo'), isNull);
        expect(reports.repository.updateCalls, isEmpty);
      });

      test('deve recusar a descrição longa antes de enviar', () async {
        expect(await sut().submit(report, 'a' * 501), isNull);

        expect(state().descriptionError, descriptionTooLongMessage);

        sut().descriptionChanged();

        expect(state().descriptionError, isNull);
      });

      test('deve voltar ao detalhe atualizado com a message do 422', () async {
        reports.repository.updateError = const BusinessRuleException(
          message: 'O reporte já recebeu votos e não pode mais ser editado.',
        );

        final outcome = await sut().submit(report, 'Nova');
        await pumpEventQueue();

        expect(
          outcome,
          const EditReportOutcome('O reporte já recebeu votos e não pode mais ser editado.'),
        );
        expect(reports.repository.getByIdCalls, hasLength(2), reason: 'O detalhe busca de novo.');
      });

      test('deve pedir outra foto no 400 da foto e no 413', () async {
        for (final error in [
          const ValidationException(
            fieldErrors: [FieldError(field: 'photo.thumbnail', message: 'Inválida.')],
          ),
          const ServerException(statusCode: 413),
        ]) {
          await sut().takePhoto();
          reports.repository.updateError = error;

          expect(await sut().submit(report, 'Buraco fundo'), isNull);

          expect(state().photoStatus, PhotoStatus.failed, reason: '$error');
          expect(state().photoError, photoNotUsableMessage);
          expect(state().newPhoto, isNull);
        }
      });

      test(
        'deve mostrar o 400 da descrição embaixo do campo e o de outro campo no aviso',
        () async {
          reports.repository.updateError = const ValidationException(
            fieldErrors: [FieldError(field: 'description', message: 'Descrição inválida.')],
          );
          await sut().submit(report, 'Nova');

          expect(state().descriptionError, 'Descrição inválida.');

          reports.repository.updateError = const ValidationException(message: 'Dados inválidos.');
          await sut().submit(report, 'Nova');

          expect(state().message, 'Dados inválidos.');
        },
      );

      test('deve continuar na tela sem conexão, com o aviso', () async {
        reports.repository.updateError = const NetworkException();

        expect(await sut().submit(report, 'Nova'), isNull);

        expect(state().message, NetworkException.defaultMessage);
        expect(state().isSubmitting, isFalse);
      });

      test('não deve salvar duas vezes', () async {
        reports.repository.updatePending = Completer();

        unawaited(sut().submit(report, 'Nova'));
        await pumpEventQueue();

        expect(state().isSubmitting, isTrue);
        expect(await sut().submit(report, 'Nova'), isNull);
        expect(reports.repository.updateCalls, hasLength(1));
        reports.repository.updatePending!.complete();
      });
    });

    test('deve descrever o estado e o resultado', () {
      expect(state().toString(), contains('photo: empty'));
      expect(state().hashCode, const EditReportState().hashCode);
      expect(const EditReportOutcome('ok').toString(), 'EditReportOutcome(ok)');
      expect(const EditReportOutcome('ok').hashCode, const EditReportOutcome('ok').hashCode);
    });
  });
}
