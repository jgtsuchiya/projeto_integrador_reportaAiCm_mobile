import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/core/location/location_service_provider.dart';
import 'package:reportaai_cm/core/media/image_compressor_provider.dart';
import 'package:reportaai_cm/core/media/photo_capture.dart';
import 'package:reportaai_cm/core/media/photo_capture_provider.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/core/utils/uuid.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/reports/domain/models/geo_location.dart';
import 'package:reportaai_cm/features/reports/domain/models/prepared_photo.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_description.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_draft.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_limits.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_location.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_photo_preparation.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_refresh.dart';
import 'package:reportaai_cm/features/reports/reports_providers.dart';

/// Estado da tela "Novo reporte": a foto, a localização, os reportes já abertos perto e o envio.
final NotifierProvider<NewReportViewModel, NewReportState> newReportViewModelProvider =
    NotifierProvider.autoDispose(NewReportViewModel.new);

/// Em que pé está a foto do reporte.
enum PhotoStatus {
  /// Sem foto: o cidadão cancelou a câmera, ou ela ainda não abriu.
  empty,

  /// A câmera está aberta.
  capturing,

  /// O app está tratando a foto (tamanho, qualidade, orientação e EXIF).
  processing,

  /// A foto está pronta para o envio.
  ready,

  /// A câmera não abriu, ou a foto não pôde ser usada: a tela pede outra.
  failed,
}

@immutable
final class NewReportState {
  const new({
    this.photoStatus = PhotoStatus.empty,
    this.photo,
    this.photoError,
    this.location = const LocationReading(LocationStatus.idle),
    this.nearby,
    this.isCheckingNearby = false,
    this.duplicateDismissed = false,
    this.isSubmitting = false,
    this.descriptionError,
    this.message,
    this.canRetry = false,
  });

  final PhotoStatus photoStatus;

  /// A foto tratada, pronta para o envio.
  final PreparedPhoto? photo;

  /// Por que a foto falhou: a câmera que não abriu ou a foto que não pôde ser usada.
  final String? photoError;

  /// A localização do aparelho, lida junto com a foto (RM21).
  final LocationReading location;

  /// Os reportes já abertos a até 30 m, do mais perto ao mais longe (RM23). `null` até a busca
  /// terminar. Uma busca que falhou fica vazia: ela não impede o envio.
  final List<Report>? nearby;

  final bool isCheckingNearby;

  /// O cidadão disse que o buraco é outro ("É outro buraco").
  final bool duplicateDismissed;

  final bool isSubmitting;

  /// O erro da descrição, da conferência antes de enviar ou do 400 da API.
  final String? descriptionError;

  /// O aviso geral, acima do "Enviar", como o 422 da API ou a falta de conexão.
  final String? message;

  /// Se o aviso é de uma falha que vale repetir (sem conexão, tempo esgotado, 5xx): o botão vira
  /// "Tentar de novo", com a mesma `Idempotency-Key` (RM24).
  final bool canRetry;

  /// O reporte mais perto, quando o aviso de reporte repetido aparece (RM23).
  Report? get duplicate => duplicateDismissed ? null : nearby?.firstOrNull;

  /// Se a foto e a localização servem, a busca dos reportes perto terminou e o aviso do reporte
  /// repetido foi respondido.
  bool get canSubmit =>
      photoStatus == PhotoStatus.ready &&
      photo != null &&
      location.status.isReady &&
      nearby != null &&
      duplicate == null &&
      !isSubmitting;

  /// Se sair da tela perde uma foto tirada: o "voltar" pergunta antes.
  bool get hasUnsentPhoto => photo != null || photoStatus == PhotoStatus.processing;

  @override
  bool operator ==(Object other) =>
      other is NewReportState &&
      other.photoStatus == photoStatus &&
      other.photo == photo &&
      other.photoError == photoError &&
      other.location == location &&
      _sameReports(other.nearby, nearby) &&
      other.isCheckingNearby == isCheckingNearby &&
      other.duplicateDismissed == duplicateDismissed &&
      other.isSubmitting == isSubmitting &&
      other.descriptionError == descriptionError &&
      other.message == message &&
      other.canRetry == canRetry;

  @override
  int get hashCode => Object.hash(
    photoStatus,
    photo,
    photoError,
    location,
    nearby == null ? null : Object.hashAll(nearby!),
    isCheckingNearby,
    duplicateDismissed,
    isSubmitting,
    descriptionError,
    message,
    canRetry,
  );

  @override
  String toString() =>
      'NewReportState(photo: ${photoStatus.name}, location: ${location.status.name}, '
      'nearby: ${nearby?.length}, duplicateDismissed: $duplicateDismissed, '
      'isSubmitting: $isSubmitting, message: $message, canRetry: $canRetry)';
}

/// Abre um reporte (RM20 a RM24): a câmera, o tratamento da foto e a localização em paralelo, o
/// aviso de reporte repetido e o envio com a `Idempotency-Key`.
///
/// A câmera abre sozinha quando a tela abre, com o e-mail do Client confirmado (RM20). Sem ele, a
/// tela mostra o aviso do e-mail, e a câmera abre quando a confirmação chega.
final class NewReportViewModel extends Notifier<NewReportState> {
  static const cameraUnavailableMessage = 'Não foi possível abrir a câmera do aparelho.';
  static const cameraDeniedMessage =
      'O app não tem acesso à câmera. Libere a câmera nas configurações do aparelho.';
  static const sendFailedMessage = 'Não foi possível enviar. Seus dados continuam aqui.';

  /// A mensagem que a tela mostra depois do envio.
  static String sentMessageFor(Report report) =>
      'Reporte enviado. Agora ele precisa de ${report.votes.confirmationsRequired} '
      'confirmações de outros cidadãos.';

  /// A chave do envio, criada quando a tela abre e a mesma em todas as tentativas: repetir depois
  /// de uma falha não cria outro reporte (RM24).
  final String idempotencyKey = randomUuidV4();

  var _started = false;

  /// Contadores das leituras: o resultado de uma foto ou de uma localização substituída (o "Tirar
  /// outra" ou o "Atualizar localização" no meio da anterior) é descartado.
  var _photoRun = 0;
  var _locationRun = 0;

  @override
  NewReportState build() {
    ref.listen(authControllerProvider, (previous, next) {
      if (_isEmailVerified(next)) unawaited(start());
    });
    if (_isEmailVerified(ref.read(authControllerProvider))) {
      unawaited(Future.microtask(start));
    }
    return const NewReportState();
  }

  /// Abre a câmera, uma vez por tela. Antes, confere a foto que o Android não entregou porque
  /// fechou o app com a câmera aberta, e a reaproveita.
  Future<void> start() async {
    if (_started || !ref.mounted) return;
    _started = true;

    Uint8List? lostPhoto;
    try {
      lostPhoto = await ref.read(photoCaptureProvider).retrieveLostPhoto();
    } on Object {
      lostPhoto = null;
    }
    if (!ref.mounted) return;

    if (lostPhoto != null) {
      await _usePhoto(lostPhoto);
    } else {
      await takePhoto();
    }
  }

  /// Abre a câmera, na abertura e no "Tirar outra": com a foto nova, a localização é lida de novo.
  /// Se o cidadão cancelar, a foto anterior continua.
  Future<void> takePhoto() async {
    if (state.isSubmitting || state.photoStatus == PhotoStatus.capturing) return;

    final previous = state;
    state = _copy(photoStatus: PhotoStatus.capturing, message: null, canRetry: false);

    Uint8List? bytes;
    String? error;
    try {
      bytes = await ref.read(photoCaptureProvider).takePhoto();
    } on CameraPermissionDeniedException {
      error = cameraDeniedMessage;
    } on Object {
      error = cameraUnavailableMessage;
    }
    if (!ref.mounted) return;

    if (error != null) {
      state = _copy(photoStatus: PhotoStatus.failed, photo: null, photoError: error);
    } else if (bytes == null) {
      state = _copy(photoStatus: previous.photoStatus, photoError: previous.photoError);
    } else {
      await _usePhoto(bytes);
    }
  }

  /// "Atualizar localização": lê a posição de novo.
  Future<void> refreshLocation() => _captureLocation();

  /// "Permitir a localização", depois da explicação da tela.
  Future<void> requestLocationPermission() => _captureLocation(requestPermission: true);

  /// "Abrir as configurações", com a permissão negada para sempre.
  Future<void> openAppSettings() async {
    await ref.read(locationServiceProvider).openAppSettings();
  }

  /// "Ativar a localização", com o GPS desligado.
  Future<void> openLocationSettings() async {
    await ref.read(locationServiceProvider).openLocationSettings();
  }

  /// O app voltou para o primeiro plano: com a localização bloqueada pelas configurações, lê de
  /// novo, porque o cidadão pode ter acabado de liberar.
  Future<void> onResume() async {
    const blockedBySettings = {
      LocationStatus.permissionDeniedForever,
      LocationStatus.serviceDisabled,
    };
    if (blockedBySettings.contains(state.location.status)) await _captureLocation();
  }

  /// "É outro buraco": o cidadão segue com o reporte novo (RM23).
  void dismissDuplicate() => state = _copy(duplicateDismissed: true);

  /// O cidadão editou a descrição: o erro dela sai da tela.
  void descriptionChanged() {
    if (state.descriptionError != null) state = _copy(descriptionError: null);
  }

  /// Envia o reporte com a descrição como está no campo. Devolve o reporte criado, ou `null`
  /// quando não enviou (o motivo fica no estado). Durante outro envio, não faz nada.
  Future<Report?> submit(String description) async {
    final current = state;
    final location = current.location.location;
    final photo = current.photo;
    if (!current.canSubmit || location == null || photo == null) return null;

    if (!isValidReportDescription(description)) {
      state = _copy(descriptionError: descriptionTooLongMessage);
      return null;
    }

    state = _copy(isSubmitting: true, descriptionError: null, message: null, canRetry: false);
    final repository = ref.read(reportRepositoryProvider);
    // Lido antes da chamada: as listas são atualizadas mesmo que a tela feche no meio.
    final refresh = ref.read(reportRefreshProvider);

    final Report report;
    try {
      report = await repository.create(
        ReportDraft(
          location: location,
          photo: photo,
          description: normalizeReportDescription(description),
        ),
        idempotencyKey: idempotencyKey,
      );
    } on Object catch (error) {
      if (ref.mounted) state = _fromSubmitError(error);
      return null;
    }

    refresh.reportsChanged();
    return report;
  }

  Future<void> _usePhoto(Uint8List bytes) async {
    final run = ++_photoRun;
    state = _copy(photoStatus: PhotoStatus.processing, photo: null, photoError: null);

    await Future.wait([_prepare(bytes, run), _captureLocation()]);
  }

  Future<void> _prepare(Uint8List bytes, int run) async {
    PreparedPhoto? photo;
    try {
      photo = await prepareReportPhoto(ref.read(imageCompressorProvider), bytes);
    } on Object {
      photo = null;
    }
    if (!ref.mounted || run != _photoRun) return;

    state = photo == null
        ? _copy(photoStatus: PhotoStatus.failed, photoError: photoNotUsableMessage)
        : _copy(photoStatus: PhotoStatus.ready, photo: photo);
  }

  Future<void> _captureLocation({bool requestPermission = false}) async {
    final run = ++_locationRun;
    final service = ref.read(locationServiceProvider);
    state = _copy(
      location: const LocationReading(LocationStatus.capturing),
      nearby: null,
      isCheckingNearby: false,
      duplicateDismissed: false,
    );

    final reading = requestPermission
        ? await requestReportLocation(service)
        : await readReportLocation(service);
    if (!ref.mounted || run != _locationRun) return;

    state = _copy(location: reading);
    if (reading.location case final location? when reading.status.isReady) {
      await _checkNearby(location.point, run);
    }
  }

  /// Os reportes já abertos a até 30 m (RM23). A busca que falha não impede o envio.
  Future<void> _checkNearby(GeoPoint point, int run) async {
    state = _copy(isCheckingNearby: true);

    List<Report> nearby;
    try {
      nearby = await ref
          .read(reportRepositoryProvider)
          .listNearby(point, radiusMeters: ReportLimits.duplicateRadiusMeters);
    } on Object {
      nearby = const [];
    }
    if (!ref.mounted || run != _locationRun) return;

    state = _copy(nearby: List<Report>.unmodifiable(nearby), isCheckingNearby: false);
  }

  NewReportState _fromSubmitError(Object error) {
    final photoRefused = switch (error) {
      ValidationException(:final fieldErrors) => fieldErrors.any(
        (fieldError) => fieldError.field.startsWith('photo'),
      ),
      ServerException(statusCode: 413) => true,
      _ => false,
    };
    if (photoRefused) {
      return _copy(
        isSubmitting: false,
        photoStatus: PhotoStatus.failed,
        photo: null,
        photoError: photoNotUsableMessage,
      );
    }

    return switch (error) {
      ValidationException() when error.messageFor('description') != null => _copy(
        isSubmitting: false,
        descriptionError: error.messageFor('description'),
      ),
      ValidationException(:final fieldErrors, :final message) => _copy(
        isSubmitting: false,
        message: fieldErrors.firstOrNull?.message ?? message,
      ),
      NetworkException() ||
      ServerException() => _copy(isSubmitting: false, message: sendFailedMessage, canRetry: true),
      _ => _copy(isSubmitting: false, message: ApiException.messageOf(error)),
    };
  }

  /// O estado de agora com os campos passados trocados. Os campos que aceitam `null` passados
  /// como `null` saem.
  NewReportState _copy({
    PhotoStatus? photoStatus,
    Object? photo = _keep,
    Object? photoError = _keep,
    LocationReading? location,
    Object? nearby = _keep,
    bool? isCheckingNearby,
    bool? duplicateDismissed,
    bool? isSubmitting,
    Object? descriptionError = _keep,
    Object? message = _keep,
    bool? canRetry,
  }) => NewReportState(
    photoStatus: photoStatus ?? state.photoStatus,
    photo: identical(photo, _keep) ? state.photo : photo as PreparedPhoto?,
    photoError: identical(photoError, _keep) ? state.photoError : photoError as String?,
    location: location ?? state.location,
    nearby: identical(nearby, _keep) ? state.nearby : nearby as List<Report>?,
    isCheckingNearby: isCheckingNearby ?? state.isCheckingNearby,
    duplicateDismissed: duplicateDismissed ?? state.duplicateDismissed,
    isSubmitting: isSubmitting ?? state.isSubmitting,
    descriptionError: identical(descriptionError, _keep)
        ? state.descriptionError
        : descriptionError as String?,
    message: identical(message, _keep) ? state.message : message as String?,
    canRetry: canRetry ?? state.canRetry,
  );
}

/// Marca o campo que o `_copy` mantém como está.
const _keep = Object();

bool _isEmailVerified(AuthState auth) => switch (auth) {
  AuthAuthenticated(:final profile) => profile.emailVerifiedAt != null,
  _ => false,
};

bool _sameReports(List<Report>? a, List<Report>? b) =>
    identical(a, b) || (a != null && b != null && listEquals(a, b));
