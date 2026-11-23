import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:reportaai_cm/core/media/image_compressor_provider.dart';
import 'package:reportaai_cm/core/media/photo_capture.dart';
import 'package:reportaai_cm/core/media/photo_capture_provider.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/reports/domain/models/prepared_photo.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_description.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_draft.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/new_report_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_detail_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_photo_preparation.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_refresh.dart';
import 'package:reportaai_cm/features/reports/reports_providers.dart';

/// Estado da tela "Editar reporte", pelo id do reporte.
final NotifierProviderFamily<EditReportViewModel, EditReportState, String>
editReportViewModelProvider = NotifierProvider.autoDispose
    .family<EditReportViewModel, EditReportState, String>(EditReportViewModel.new);

@immutable
final class EditReportState {
  const new({
    this.photoStatus = PhotoStatus.empty,
    this.newPhoto,
    this.photoError,
    this.isSubmitting = false,
    this.descriptionError,
    this.message,
  });

  /// A troca da foto: `empty` enquanto a foto do reporte continua a mesma.
  final PhotoStatus photoStatus;

  /// A foto nova, tratada, que substitui a do reporte no "Salvar".
  final PreparedPhoto? newPhoto;

  final String? photoError;
  final bool isSubmitting;

  /// O erro da descrição, da conferência antes de enviar ou do 400 da API.
  final String? descriptionError;

  /// O aviso geral, acima do "Salvar", como sem conexão.
  final String? message;

  /// Se a foto nova está sendo tirada ou tratada: o "Salvar" espera.
  bool get isChangingPhoto =>
      photoStatus == PhotoStatus.capturing || photoStatus == PhotoStatus.processing;

  @override
  bool operator ==(Object other) =>
      other is EditReportState &&
      other.photoStatus == photoStatus &&
      other.newPhoto == newPhoto &&
      other.photoError == photoError &&
      other.isSubmitting == isSubmitting &&
      other.descriptionError == descriptionError &&
      other.message == message;

  @override
  int get hashCode =>
      Object.hash(photoStatus, newPhoto, photoError, isSubmitting, descriptionError, message);

  @override
  String toString() =>
      'EditReportState(photo: ${photoStatus.name}, newPhoto: $newPhoto, '
      'isSubmitting: $isSubmitting, descriptionError: $descriptionError, message: $message)';
}

/// O que a tela faz depois do "Salvar": volta ao detalhe com a [message] (o reporte salvo, ou o
/// 422 de quem votou enquanto a tela estava aberta).
@immutable
final class EditReportOutcome {
  const new(this.message);

  final String message;

  @override
  bool operator ==(Object other) => other is EditReportOutcome && other.message == message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'EditReportOutcome($message)';
}

/// Edita a descrição e a foto do reporte (RM25), enquanto ninguém votou. A localização não muda.
/// Só o que mudou vai para a API.
final class EditReportViewModel extends Notifier<EditReportState> {
  new(this.reportId);

  static const savedMessage = 'Reporte atualizado.';

  final String reportId;

  var _photoRun = 0;

  @override
  EditReportState build() => const EditReportState();

  /// O que muda entre o [report] e a tela: a descrição do campo (sem os espaços das pontas; vazia
  /// apaga) e a foto nova.
  ReportChanges changesFrom(Report report, String description) {
    final normalized = normalizeReportDescription(description);
    return ReportChanges(
      description: normalized == report.description ? null : normalized ?? '',
      photo: state.newPhoto,
    );
  }

  /// "Trocar a foto": abre a câmera e trata a foto nova, como na abertura (RM22). Se o cidadão
  /// cancelar, nada muda.
  Future<void> takePhoto() async {
    if (state.isSubmitting || state.isChangingPhoto) return;

    final previous = state;
    final run = ++_photoRun;
    state = _copy(photoStatus: PhotoStatus.capturing, message: null);

    Uint8List? bytes;
    String? error;
    try {
      bytes = await ref.read(photoCaptureProvider).takePhoto();
    } on CameraPermissionDeniedException {
      error = NewReportViewModel.cameraDeniedMessage;
    } on Object {
      error = NewReportViewModel.cameraUnavailableMessage;
    }
    if (!ref.mounted || run != _photoRun) return;

    if (error != null) {
      state = _copy(photoStatus: PhotoStatus.failed, newPhoto: null, photoError: error);
      return;
    }
    if (bytes == null) {
      state = _copy(photoStatus: previous.photoStatus, photoError: previous.photoError);
      return;
    }

    state = _copy(photoStatus: PhotoStatus.processing, newPhoto: null, photoError: null);
    PreparedPhoto? photo;
    try {
      photo = await prepareReportPhoto(ref.read(imageCompressorProvider), bytes);
    } on Object {
      photo = null;
    }
    if (!ref.mounted || run != _photoRun) return;

    state = photo == null
        ? _copy(photoStatus: PhotoStatus.failed, photoError: photoNotUsableMessage)
        : _copy(photoStatus: PhotoStatus.ready, newPhoto: photo);
  }

  /// O cidadão editou a descrição: o erro dela sai da tela.
  void descriptionChanged() {
    if (state.descriptionError != null) state = _copy(descriptionError: null);
  }

  /// Salva o que mudou no [report]. Devolve o [EditReportOutcome] quando a tela volta ao detalhe,
  /// ou `null` quando ela continua aberta (sem mudança, com um erro do campo, sem conexão).
  Future<EditReportOutcome?> submit(Report report, String description) async {
    if (state.isSubmitting || state.isChangingPhoto) return null;

    final changes = changesFrom(report, description);
    if (changes.isEmpty) return null;
    if (!isValidReportDescription(description)) {
      state = _copy(descriptionError: descriptionTooLongMessage);
      return null;
    }

    state = _copy(isSubmitting: true, descriptionError: null, message: null);
    // Lidos antes da chamada: o detalhe e a lista são atualizados mesmo que a tela feche no meio.
    final repository = ref.read(reportRepositoryProvider);
    final refresh = ref.read(reportRefreshProvider);
    final detail = ref.read(reportDetailViewModelProvider(reportId).notifier);

    final Report updated;
    try {
      updated = await repository.update(reportId, changes);
    } on BusinessRuleException catch (error) {
      // Alguém votou enquanto a tela estava aberta (RN33): o detalhe busca o reporte de novo.
      refresh.reportChanged(reportId);
      if (ref.mounted) state = _copy(isSubmitting: false);
      return EditReportOutcome(error.message);
    } on Object catch (error) {
      if (ref.mounted) state = _fromSubmitError(error);
      return null;
    }

    detail.replace(updated);
    refresh.reportsChanged();
    if (ref.mounted) state = _copy(isSubmitting: false);
    return const EditReportOutcome(savedMessage);
  }

  EditReportState _fromSubmitError(Object error) => switch (error) {
    ValidationException(:final fieldErrors)
        when fieldErrors.any((fieldError) => fieldError.field.startsWith('photo')) =>
      _copy(
        isSubmitting: false,
        photoStatus: PhotoStatus.failed,
        newPhoto: null,
        photoError: photoNotUsableMessage,
      ),
    ServerException(statusCode: 413) => _copy(
      isSubmitting: false,
      photoStatus: PhotoStatus.failed,
      newPhoto: null,
      photoError: photoNotUsableMessage,
    ),
    ValidationException() when error.messageFor('description') != null => _copy(
      isSubmitting: false,
      descriptionError: error.messageFor('description'),
    ),
    ValidationException(:final fieldErrors, :final message) => _copy(
      isSubmitting: false,
      message: fieldErrors.firstOrNull?.message ?? message,
    ),
    _ => _copy(isSubmitting: false, message: ApiException.messageOf(error)),
  };

  /// O estado de agora com os campos passados trocados. Os campos que aceitam `null` passados
  /// como `null` saem.
  EditReportState _copy({
    PhotoStatus? photoStatus,
    Object? newPhoto = _keep,
    Object? photoError = _keep,
    bool? isSubmitting,
    Object? descriptionError = _keep,
    Object? message = _keep,
  }) => EditReportState(
    photoStatus: photoStatus ?? state.photoStatus,
    newPhoto: identical(newPhoto, _keep) ? state.newPhoto : newPhoto as PreparedPhoto?,
    photoError: identical(photoError, _keep) ? state.photoError : photoError as String?,
    isSubmitting: isSubmitting ?? state.isSubmitting,
    descriptionError: identical(descriptionError, _keep)
        ? state.descriptionError
        : descriptionError as String?,
    message: identical(message, _keep) ? state.message : message as String?,
  );
}

/// Marca o campo que o `_copy` mantém como está.
const _keep = Object();
