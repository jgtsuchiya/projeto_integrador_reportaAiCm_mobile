import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';

import '../../../../support/fake_profile_repository.dart';

void main() {
  group('UnauthenticatedReason', () {
    test('deve ter a mensagem de cada regra do app', () {
      expect(
        UnauthenticatedReason.sessionExpired.message,
        'Sua sessão expirou. Entre de novo.', // RM07
      );
      expect(
        UnauthenticatedReason.roleNotAllowed.message,
        'Este aplicativo é para cidadãos. Administradores usam o painel web.', // RM01
      );
      expect(
        UnauthenticatedReason.secondFactorPending.message,
        'A verificação em duas etapas ainda não está disponível no app.', // RM08
      );
    });

    test('deve usar no fim da sessão a mesma mensagem do 401 da API', () {
      expect(UnauthenticatedReason.sessionExpired.message, UnauthorizedException.defaultMessage);
    });
  });

  group('AuthState', () {
    test('deve comparar pelo valor', () {
      expect(const AuthChecking(), const AuthChecking());
      expect(const AuthUnauthenticated(), const AuthUnauthenticated());
      expect(
        const AuthUnauthenticated(reason: UnauthenticatedReason.roleNotAllowed),
        const AuthUnauthenticated(reason: UnauthenticatedReason.roleNotAllowed),
      );
      expect(AuthAuthenticated(clientProfile), AuthAuthenticated(clientProfile));
      expect(const AuthLoadFailed(NetworkException()), const AuthLoadFailed(NetworkException()));
      expect({
        const AuthChecking().hashCode,
        const AuthUnauthenticated().hashCode,
        AuthAuthenticated(clientProfile).hashCode,
        const AuthLoadFailed(NetworkException()).hashCode,
      }, hasLength(4));
    });

    test('deve diferenciar o login com e sem o motivo', () {
      expect(
        const AuthUnauthenticated(),
        isNot(const AuthUnauthenticated(reason: UnauthenticatedReason.sessionExpired)),
      );
      expect(AuthAuthenticated(clientProfile), isNot(AuthAuthenticated(adminProfile)));
    });

    test('não deve mostrar o CPF no texto de log (RM09)', () {
      final text = AuthAuthenticated(clientProfile).toString();

      expect(text, isNot(contains(clientProfile.cpf)));
      expect(
        const AuthUnauthenticated(reason: UnauthenticatedReason.sessionExpired).toString(),
        'AuthUnauthenticated(reason: sessionExpired)',
      );
      expect(const AuthChecking().toString(), 'AuthChecking()');
      expect(
        const AuthLoadFailed(NetworkException()).toString(),
        contains(NetworkException.defaultMessage),
      );
    });
  });
}
