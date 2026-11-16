import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/auth/domain/models/sign_in_result.dart';
import 'package:reportaai_cm/features/auth/domain/models/sign_in_validation.dart';

void main() {
  group('validateSignIn', () {
    test('deve aceitar o e-mail no formato e a senha preenchida', () {
      expect(
        validateSignIn(email: 'maria.silva@exemplo.com', password: 'SenhaSecreta123'),
        isEmpty,
      );
    });

    test('deve pedir o e-mail e a senha quando estão vazios', () {
      expect(validateSignIn(email: '', password: ''), {
        SignInField.email: SignInFieldError.emailRequiredMessage,
        SignInField.password: SignInFieldError.passwordRequiredMessage,
      });
    });

    test('deve tratar o e-mail só com espaços como vazio', () {
      expect(validateSignIn(email: '   ', password: 'Senha'), {
        SignInField.email: SignInFieldError.emailRequiredMessage,
      });
    });

    test('deve recusar o e-mail fora do formato', () {
      expect(validateSignIn(email: 'maria@exemplo', password: 'Senha'), {
        SignInField.email: SignInFieldError.emailInvalidMessage,
      });
    });

    test('deve aceitar o e-mail com espaços nas pontas e maiúsculas, como a API (RN02)', () {
      expect(validateSignIn(email: ' Maria.Silva@Exemplo.COM ', password: 'Senha'), isEmpty);
    });

    test('não deve conferir a política de senha, só que ela está preenchida (RM05)', () {
      expect(validateSignIn(email: 'maria.silva@exemplo.com', password: '1'), isEmpty);
      expect(validateSignIn(email: 'maria.silva@exemplo.com', password: ' '), isEmpty);
    });
  });
}
