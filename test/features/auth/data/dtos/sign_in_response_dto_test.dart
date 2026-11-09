import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/auth/data/dtos/sign_in_response_dto.dart';
import 'package:reportaai_cm/features/auth/domain/models/sign_in_result.dart';

void main() {
  group('SignInResponseDto', () {
    SignInResult resultOf(Object? json) => SignInResponseDto.fromJson(json).toModel();

    test('deve converter o OK em SignInSuccess', () {
      expect(
        resultOf({
          'status': 'OK',
          'user': {'id': 'user-1'},
        }),
        const SignInSuccess(),
      );
    });

    test('deve converter o WRONG_CREDENTIALS_ERROR em SignInWrongCredentials', () {
      expect(resultOf({'status': 'WRONG_CREDENTIALS_ERROR'}), const SignInWrongCredentials());
    });

    test('deve converter o GENERAL_ERROR em SignInLocked, com a message da API (RM03)', () {
      final sut = resultOf({
        'status': 'GENERAL_ERROR',
        'message': 'Muitas tentativas. Tente novamente em alguns minutos.',
      });

      expect(sut, const SignInLocked('Muitas tentativas. Tente novamente em alguns minutos.'));
    });

    group('FIELD_ERROR', () {
      Map<String, Object?> fieldError(List<Map<String, String>> formFields) => {
        'status': 'FIELD_ERROR',
        'formFields': formFields,
      };

      test('deve trocar a mensagem do e-mail fora do formato pela do app', () {
        final sut = resultOf(
          fieldError([
            {'id': 'email', 'error': 'Email is invalid'},
          ]),
        );

        expect(
          sut,
          const SignInFieldError({SignInField.email: SignInFieldError.emailInvalidMessage}),
        );
      });

      test('deve trocar a mensagem dos campos vazios pelas do app', () {
        final sut = resultOf(
          fieldError([
            {'id': 'email', 'error': 'Field is not optional'},
            {'id': 'password', 'error': 'Field is not optional'},
          ]),
        );

        expect(
          sut,
          const SignInFieldError({
            SignInField.email: SignInFieldError.emailRequiredMessage,
            SignInField.password: SignInFieldError.passwordRequiredMessage,
          }),
        );
      });

      test('deve ignorar um campo que não é do formulário', () {
        final sut = resultOf(
          fieldError([
            {'id': 'email', 'error': 'Email is invalid'},
            {'id': 'name', 'error': 'Field is not optional'},
          ]),
        );

        expect(
          sut,
          const SignInFieldError({SignInField.email: SignInFieldError.emailInvalidMessage}),
        );
      });

      test('deve recusar o FIELD_ERROR sem um campo do formulário', () {
        for (final json in <Map<String, Object?>>[
          {'status': 'FIELD_ERROR'},
          fieldError([]),
          fieldError([
            {'id': 'name', 'error': 'Field is not optional'},
          ]),
        ]) {
          expect(() => resultOf(json), throwsFormatException, reason: '$json');
        }
      });
    });

    test('deve recusar o GENERAL_ERROR sem a message', () {
      for (final json in <Map<String, Object?>>[
        {'status': 'GENERAL_ERROR'},
        {'status': 'GENERAL_ERROR', 'message': '  '},
        {'status': 'GENERAL_ERROR', 'message': 42},
      ]) {
        expect(() => resultOf(json), throwsFormatException, reason: '$json');
      }
    });

    test('deve recusar um status que o app não conhece', () {
      expect(
        () => resultOf({'status': 'SIGN_IN_NOT_ALLOWED', 'reason': 'Cannot sign in'}),
        throwsFormatException,
      );
    });

    test('deve recusar o JSON fora do formato', () {
      for (final json in <Object?>[
        null,
        'OK',
        <String, Object?>{},
        {'status': 200},
      ]) {
        expect(() => SignInResponseDto.fromJson(json), throwsFormatException, reason: '$json');
      }
    });
  });
}
