import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/auth/data/dtos/sign_in_request_dto.dart';

void main() {
  group('SignInRequestDto', () {
    test('deve montar o corpo no formato do SuperTokens', () {
      const sut = SignInRequestDto(email: 'maria.silva@exemplo.com', password: 'Senha123');

      expect(sut.toJson(), {
        'formFields': [
          {'id': 'email', 'value': 'maria.silva@exemplo.com'},
          {'id': 'password', 'value': 'Senha123'},
        ],
      });
    });

    test('deve enviar o e-mail sem os espaços das pontas e em minúsculas (RN02)', () {
      const sut = SignInRequestDto(email: '  Maria.Silva@Exemplo.COM ', password: 'Senha123');

      expect(sut.toJson()['formFields'], [
        {'id': 'email', 'value': 'maria.silva@exemplo.com'},
        {'id': 'password', 'value': 'Senha123'},
      ]);
    });

    test('deve enviar a senha como foi digitada', () {
      const sut = SignInRequestDto(email: 'maria.silva@exemplo.com', password: ' Senha 123 ');

      expect(sut.toJson()['formFields'], [
        {'id': 'email', 'value': 'maria.silva@exemplo.com'},
        {'id': 'password', 'value': ' Senha 123 '},
      ]);
    });
  });
}
