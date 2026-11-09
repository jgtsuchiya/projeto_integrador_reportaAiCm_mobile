import 'package:dio/dio.dart';
import 'package:reportaai_cm/core/network/api_error_mapper.dart';
import 'package:reportaai_cm/features/profile/data/dtos/user_profile_dto.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_profile.dart';
import 'package:reportaai_cm/features/profile/domain/repositories/profile_repository.dart';

/// [ProfileRepository] que chama o `GET /api/users/me` pelo `Dio` compartilhado, com a sessão
/// enviada e renovada pelo SDK do SuperTokens.
final class ApiProfileRepository implements ProfileRepository {
  const new(this._dio);

  final Dio _dio;

  @override
  Future<UserProfile> getMe() => callApi(() async {
    final response = await _dio.get<Object?>('/users/me');
    return UserProfileDto.fromJson(response.data).toModel();
  });
}
