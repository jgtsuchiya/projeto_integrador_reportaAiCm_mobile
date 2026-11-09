import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/auth/domain/models/sign_in_result.dart';

void main() {
  // Montados fora de um const, como no DTO, para não comparar a mesma instância.
  SignInLocked locked(String message) => SignInLocked(message);
  SignInRateLimited rateLimited(int seconds) =>
      SignInRateLimited(retryAfter: Duration(seconds: seconds));
  SignInFieldError fieldError(Map<SignInField, String> errors) => SignInFieldError(errors);

  group('SignInResult', () {
    test('deve comparar pelo tipo e pelo valor', () {
      expect(const SignInSuccess(), const SignInSuccess());
      expect(const SignInSuccess(), isNot(const SignInWrongCredentials()));
      expect(const SignInWrongCredentials(), isNot(const SignInSuccess()));
      expect(locked('Bloqueado.'), const SignInLocked('Bloqueado.'));
      expect(locked('Bloqueado.'), isNot(const SignInLocked('Outra.')));
      expect(rateLimited(42), const SignInRateLimited(retryAfter: Duration(seconds: 42)));
      expect(rateLimited(42), isNot(const SignInRateLimited(retryAfter: Duration(seconds: 41))));
    });

    test('deve ter o mesmo hashCode quando é igual', () {
      expect(const SignInSuccess().hashCode, isNot(const SignInWrongCredentials().hashCode));
      expect(locked('Bloqueado.').hashCode, const SignInLocked('Bloqueado.').hashCode);
      expect(
        rateLimited(42).hashCode,
        const SignInRateLimited(retryAfter: Duration(seconds: 42)).hashCode,
      );
    });

    test('deve descrever o resultado no toString, para as mensagens dos testes', () {
      expect(const SignInSuccess().toString(), 'SignInSuccess()');
      expect(const SignInWrongCredentials().toString(), 'SignInWrongCredentials()');
      expect(locked('Bloqueado.').toString(), 'SignInLocked(Bloqueado.)');
      expect(rateLimited(42).toString(), contains('retryAfter: 0:00:42'));
      expect(
        fieldError({SignInField.email: SignInFieldError.emailInvalidMessage}).toString(),
        'SignInFieldError({SignInField.email: E-mail inválido.})',
      );
    });

    test('deve esperar a janela inteira do limite por IP sem o Retry-After (RN18)', () {
      expect(SignInRateLimited.defaultRetryAfter, const Duration(minutes: 1));
    });
  });

  group('SignInFieldError', () {
    test('deve devolver a mensagem de cada campo, e null no campo aceito', () {
      const sut = SignInFieldError({SignInField.email: SignInFieldError.emailInvalidMessage});

      expect(sut.messageFor(SignInField.email), 'E-mail inválido.');
      expect(sut.messageFor(SignInField.password), isNull);
    });

    test('deve comparar pelos campos e mensagens, em qualquer ordem', () {
      final sut = fieldError({
        SignInField.email: SignInFieldError.emailRequiredMessage,
        SignInField.password: SignInFieldError.passwordRequiredMessage,
      });
      final sameInOtherOrder = fieldError({
        SignInField.password: SignInFieldError.passwordRequiredMessage,
        SignInField.email: SignInFieldError.emailRequiredMessage,
      });

      expect(sut, sameInOtherOrder);
      expect(sut.hashCode, sameInOtherOrder.hashCode);
      expect(sut, isNot(fieldError({SignInField.email: SignInFieldError.emailRequiredMessage})));
      expect(
        fieldError({SignInField.email: SignInFieldError.emailRequiredMessage}),
        isNot(fieldError({SignInField.email: SignInFieldError.emailInvalidMessage})),
      );
    });
  });
}
