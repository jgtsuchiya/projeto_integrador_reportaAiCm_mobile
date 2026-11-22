import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/profile/data/repositories/api_profile_repository.dart';

import '../../../../support/fake_http_adapter.dart';
import '../../../../support/fake_profile_repository.dart';

void main() {
  group('ApiProfileRepository', () {
    late FakeHttpAdapter adapter;
    late ApiProfileRepository sut;

    setUp(() {
      adapter = FakeHttpAdapter();
      sut = ApiProfileRepository(fakeDio(adapter));
    });

    test('deve chamar o GET /api/users/me e devolver o modelo', () async {
      adapter.reply(200, body: clientProfileJson);

      final result = await sut.getMe();

      expect(result, clientProfile);
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.uri.path, '/api/users/me');
    });

    test('deve lançar a UnauthorizedException quando a sessão acabou', () async {
      adapter.reply(401, body: {'message': 'unauthorised'});

      await expectLater(sut.getMe(), throwsA(isA<UnauthorizedException>()));
    });

    test('deve lançar a SecondFactorPendingException com a sessão pendente', () async {
      adapter.reply(
        403,
        body: {
          'message': 'invalid claim',
          'claimValidationErrors': [
            {'id': 'mfa-verified'},
          ],
        },
      );

      await expectLater(sut.getMe(), throwsA(isA<SecondFactorPendingException>()));
    });

    test('deve lançar a NetworkException com a API desligada', () async {
      adapter.failWith(DioExceptionType.connectionError);

      await expectLater(sut.getMe(), throwsA(isA<NetworkException>()));
    });

    test('deve lançar a ServerException com a resposta fora do formato', () async {
      adapter.reply(200, body: {'id': 'user-1', 'role': 'CLIENT'});

      await expectLater(sut.getMe(), throwsA(isA<ServerException>()));
    });
  });
}
