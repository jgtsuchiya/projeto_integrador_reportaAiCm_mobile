import 'dart:convert';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:reportaai_cm/core/network/api_error_mapper.dart';
import 'package:reportaai_cm/features/reports/data/dtos/report_dto.dart';
import 'package:reportaai_cm/features/reports/data/dtos/report_list_dtos.dart';
import 'package:reportaai_cm/features/reports/data/dtos/report_photo_dto.dart';
import 'package:reportaai_cm/features/reports/data/dtos/report_request_dtos.dart';
import 'package:reportaai_cm/features/reports/domain/models/geo_location.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_draft.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_limits.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_page.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';
import 'package:reportaai_cm/features/reports/domain/models/vote_type.dart';
import 'package:reportaai_cm/features/reports/domain/repositories/report_repository.dart';

/// [ReportRepository] que chama as rotas de `/api/reports` pelo `Dio` compartilhado, com a sessão
/// enviada e renovada pelo SDK do SuperTokens.
///
/// A foto grande vira um texto de até 2,7 MB em base64: o encode do envio e o decode da resposta
/// rodam no `Isolate.run`, fora da thread da tela, para ela não engasgar.
final class ApiReportRepository implements ReportRepository {
  const new(this._dio);

  /// O tempo limite do envio e da resposta da abertura e da edição, maior que o padrão do `Dio`:
  /// a foto pode levar alguns segundos para subir em rede móvel.
  static const uploadTimeout = Duration(seconds: 60);

  final Dio _dio;

  @override
  Future<Report> create(ReportDraft draft, {required String idempotencyKey}) => callApi(() async {
    final body = await _encodeOpenBody(draft);
    final response = await _dio.post<Object?>(
      '/reports',
      data: body,
      options: Options(
        headers: {'Idempotency-Key': idempotencyKey},
        sendTimeout: uploadTimeout,
        receiveTimeout: uploadTimeout,
      ),
    );
    return ReportDto.fromJson(response.data).toModel();
  });

  @override
  Future<ReportPage> listMine({
    int page = 1,
    int pageSize = ReportLimits.pageSize,
    ReportStatus? status,
  }) => callApi(() async {
    final response = await _dio.get<Object?>(
      '/reports/mine',
      queryParameters: {'page': page, 'pageSize': pageSize, 'status': ?status?.apiName},
    );
    return ReportPageDto.fromJson(response.data).toModel();
  });

  @override
  Future<List<Report>> listNearby(GeoPoint point, {required int radiusMeters}) => callApi(() async {
    final response = await _dio.get<Object?>(
      '/reports/nearby',
      queryParameters: {
        'latitude': point.latitude,
        'longitude': point.longitude,
        'radiusMeters': radiusMeters,
      },
    );
    return NearbyReportsDto.fromJson(response.data).toModel();
  });

  @override
  Future<Report> getById(String id) => callApi(() async {
    final response = await _dio.get<Object?>('/reports/${Uri.encodeComponent(id)}');
    return ReportDto.fromJson(response.data).toModel();
  });

  @override
  Future<ReportPhotoImage> getPhoto(String reportId, ReportPhotoSize size) => callApi(() async {
    final response = await _dio.get<Object?>(
      '/reports/${Uri.encodeComponent(reportId)}/photo',
      queryParameters: {'size': size.apiName},
    );
    final data = response.data;

    // A miniatura tem até 100 KB: o decode dela não pesa na tela.
    return switch (size) {
      ReportPhotoSize.full => await _decodePhoto(data),
      ReportPhotoSize.thumbnail => ReportPhotoDto.fromJson(data).toModel(),
    };
  });

  @override
  Future<Report> update(String id, ReportChanges changes) => callApi(() async {
    final body = changes.photo == null
        ? EditReportRequestDto(changes).toJson()
        : await _encodeEditBody(changes);
    final response = await _dio.patch<Object?>(
      '/reports/${Uri.encodeComponent(id)}',
      data: body,
      options: Options(sendTimeout: uploadTimeout, receiveTimeout: uploadTimeout),
    );
    return ReportDto.fromJson(response.data).toModel();
  });

  @override
  Future<void> delete(String id) => callApi(() async {
    // A resposta é um 204, sem corpo.
    await _dio.delete<Object?>('/reports/${Uri.encodeComponent(id)}');
  });

  @override
  Future<Report> vote(String id, VoteType vote, GeoLocation location) => callApi(() async {
    // A resposta é um 201 com o reporte atualizado. A localização vai só no corpo: o
    // `ApiLogInterceptor` a esconde do log (RM29).
    final response = await _dio.post<Object?>(
      '/reports/${Uri.encodeComponent(id)}/votes',
      data: VoteRequestDto(vote, location).toJson(),
    );
    return ReportDto.fromJson(response.data).toModel();
  });
}

// As funções do `Isolate.run` ficam fora da classe: a closure leva para o outro isolate só o que
// ela usa. Criada dentro de um método, ela levaria também o `this` e o `Dio`, que não podem ir.

/// O corpo da abertura em JSON, com a foto em base64, fora da thread da tela.
Future<String> _encodeOpenBody(ReportDraft draft) =>
    Isolate.run(() => jsonEncode(OpenReportRequestDto(draft).toJson()));

/// O corpo da edição com a foto nova em JSON, fora da thread da tela.
Future<String> _encodeEditBody(ReportChanges changes) =>
    Isolate.run(() => jsonEncode(EditReportRequestDto(changes).toJson()));

/// A foto grande em bytes, a partir do base64 da resposta, fora da thread da tela.
Future<ReportPhotoImage> _decodePhoto(Object? data) =>
    Isolate.run(() => ReportPhotoDto.fromJson(data).toModel());
