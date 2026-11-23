import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/auth/data/dtos/register_client_request_dto.dart';
import 'package:reportaai_cm/features/auth/domain/models/client_registration.dart';

void main() {
  group('RegisterClientRequestDto', () {
    test('deve montar o corpo do POST /api/clients, com os campos no formato da API', () {
      const sut = RegisterClientRequestDto(
        ClientRegistration(
          name: '  Maria da Silva  ',
          email: ' Maria.Silva@Exemplo.com ',
          password: ' senha forte 1 ',
          cpf: '52998224725',
          phone: '44999998888',
          birthDate: '1990-05-20',
        ),
      );

      expect(sut.toJson(), {
        'name': 'Maria da Silva',
        'email': 'maria.silva@exemplo.com',
        // A senha vai como foi digitada, com os espaços.
        'password': ' senha forte 1 ',
        'cpf': '52998224725',
        'phone': '44999998888',
        'birthDate': '1990-05-20',
      });
    });
  });
}
