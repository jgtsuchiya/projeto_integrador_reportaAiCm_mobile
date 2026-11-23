import 'package:dio/dio.dart';
import 'package:reportaai_cm/core/network/api_error_mapper.dart';
import 'package:reportaai_cm/features/account/data/dtos/user_session_dto.dart';
import 'package:reportaai_cm/features/account/domain/models/user_session.dart';
import 'package:reportaai_cm/features/account/domain/repositories/sessions_repository.dart';

/// [SessionsRepository] que chama as rotas de `/api/users/me/sessions` pelo `Dio` compartilhado.
final class ApiSessionsRepository implements SessionsRepository {
  const new(this._dio);

  final Dio _dio;

  @override
  Future<List<UserSession>> list() => callApi(() async {
    final response = await _dio.get<Object?>('/users/me/sessions');
    return [for (final dto in UserSessionDto.listFromJson(response.data)) dto.toModel()];
  });

  @override
  Future<void> revoke(String id) => callApi(() async {
    // O id é o do SuperTokens: vai codificado, como um pedaço do caminho.
    await _dio.delete<Object?>('/users/me/sessions/${Uri.encodeComponent(id)}');
  });

  @override
  Future<void> revokeOthers() => callApi(() async {
    await _dio.delete<Object?>('/users/me/sessions');
  });
}
