import 'package:dio/dio.dart';
import 'package:reportaai_cm/core/network/api_error_mapper.dart';
import 'package:reportaai_cm/features/health/data/dtos/health_status_dto.dart';
import 'package:reportaai_cm/features/health/domain/models/health_status.dart';
import 'package:reportaai_cm/features/health/domain/repositories/health_repository.dart';

/// [HealthRepository] que chama o `GET /api/health` pelo `Dio` compartilhado.
final class ApiHealthRepository implements HealthRepository {
  const new(this._dio);

  final Dio _dio;

  @override
  Future<HealthStatus> check() => callApi(() async {
    final response = await _dio.get<Object?>('/health');
    return HealthStatusDto.fromJson(response.data).toModel();
  });
}
