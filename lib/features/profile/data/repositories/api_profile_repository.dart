import 'package:dio/dio.dart';
import 'package:reportaai_cm/core/network/api_error_mapper.dart';
import 'package:reportaai_cm/features/profile/data/dtos/user_profile_dto.dart';
import 'package:reportaai_cm/features/profile/domain/models/profile_changes.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_profile.dart';
import 'package:reportaai_cm/features/profile/domain/repositories/profile_repository.dart';

/// [ProfileRepository] que chama as rotas de `/api/users/me` pelo `Dio` compartilhado, com a
/// sessão enviada e renovada pelo SDK do SuperTokens.
final class ApiProfileRepository implements ProfileRepository {
  const new(this._dio);

  final Dio _dio;

  @override
  Future<UserProfile> getMe() => callApi(() async {
    final response = await _dio.get<Object?>('/users/me');
    return UserProfileDto.fromJson(response.data).toModel();
  });

  @override
  Future<void> resendEmailVerification() => callApi(() async {
    // A resposta é um 204, sem corpo.
    await _dio.post<Object?>('/users/me/email-verification');
  });

  @override
  Future<UserProfile> updateMe(ProfileChanges changes) => callApi(() async {
    final ProfileChanges(:name, :phone, :birthDate) = changes;
    final response = await _dio.patch<Object?>(
      '/users/me',
      // Só os campos que mudaram: a API ignora os que não vêm.
      data: {'name': ?name?.trim(), 'phone': ?phone, 'birthDate': ?birthDate},
    );
    return UserProfileDto.fromJson(response.data).toModel();
  });

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) =>
      callApi(() async {
        // A resposta é um 204, sem corpo. As senhas vão como foram digitadas.
        await _dio.patch<Object?>(
          '/users/me/password',
          data: {'currentPassword': currentPassword, 'newPassword': newPassword},
        );
      });

  @override
  Future<UserProfile> setMfa({required bool enabled, required String password}) =>
      callApi(() async {
        final response = await _dio.patch<Object?>(
          '/users/me/mfa',
          data: {'enabled': enabled, 'password': password},
        );
        return UserProfileDto.fromJson(response.data).toModel();
      });

  @override
  Future<void> deleteAccount({required String password}) => callApi(() async {
    // A resposta é um 204, sem corpo, e sem os headers que apagariam a sessão do aparelho.
    await _dio.delete<Object?>('/users/me', data: {'password': password});
  });
}
