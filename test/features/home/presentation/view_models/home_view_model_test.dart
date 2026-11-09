import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/home/presentation/view_models/home_view_model.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_profile.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';

void main() {
  group('HomeState', () {
    test('deve comparar pelo valor', () {
      expect(const HomeState(refreshError: 'Erro'), const HomeState(refreshError: 'Erro'));
      expect(
        const HomeState(refreshError: 'Erro').hashCode,
        const HomeState(refreshError: 'Erro').hashCode,
      );
      expect(const HomeState(refreshError: 'Erro'), isNot(const HomeState()));
      expect(const HomeState().toString(), 'HomeState(refreshError: null)');
    });
  });

  group('HomeViewModel', () {
    late AuthFakes fakes;
    late ProviderContainer container;

    /// A tela inicial aberta: o listen mantém o ViewModel vivo entre as leituras.
    late ProviderSubscription<HomeState> screen;

    final verifiedProfile = clientProfileWith(emailVerifiedAt: DateTime.utc(2026, 10, 5, 12));

    /// O Client dentro, com a tela inicial aberta.
    setUp(() async {
      fakes = AuthFakes(signedIn: true);
      container = ProviderContainer.test(overrides: fakes.overrides, retry: noAutomaticRetry)
        ..listen(authControllerProvider, (_, _) {});
      await pumpEventQueue();
      screen = container.listen(homeViewModelProvider, (_, _) {});
    });

    HomeViewModel sut() => container.read(homeViewModelProvider.notifier);
    HomeState state() => container.read(homeViewModelProvider);
    AuthState authState() => container.read(authControllerProvider);

    test('deve começar sem aviso', () {
      expect(state(), const HomeState());
    });

    test('deve atualizar o perfil do AuthController, sem aviso', () async {
      fakes.profile.result = verifiedProfile;

      await sut().refresh();

      expect(authState(), AuthAuthenticated(verifiedProfile));
      expect(state(), const HomeState());
      expect(fakes.profile.calls, 2);
    });

    test('deve avisar sem conexão e manter o perfil que já estava na tela', () async {
      fakes.profile.error = const NetworkException();

      await sut().refresh();

      expect(state(), const HomeState(refreshError: NetworkException.defaultMessage));
      expect(authState(), AuthAuthenticated(clientProfile));
    });

    test('deve avisar com a API fora do ar', () async {
      fakes.profile.error = const ServerException(statusCode: 503);

      await sut().refresh();

      expect(state().refreshError, ServerException.defaultMessage);
    });

    test('deve tirar o aviso anterior assim que a atualização começa', () async {
      fakes.profile.error = const NetworkException();
      await sut().refresh();
      fakes.profile.error = null;
      final profile = fakes.profile.pending = Completer<UserProfile>();

      final refresh = sut().refresh();

      expect(state(), const HomeState());

      profile.complete(verifiedProfile);
      await refresh;

      expect(state(), const HomeState());
      expect(authState(), AuthAuthenticated(verifiedProfile));
    });

    test('não deve avisar quando a sessão acabou: o redirect leva ao login (RM07)', () async {
      fakes.profile.error = const UnauthorizedException();

      await sut().refresh();

      expect(state(), const HomeState());
      expect(authState(), const AuthUnauthenticated(reason: UnauthenticatedReason.sessionExpired));
    });

    test('não deve mudar o estado depois de a tela fechar', () async {
      final profile = fakes.profile.pending = Completer<UserProfile>();
      final refresh = sut().refresh();

      screen.close();
      await pumpEventQueue();
      profile.completeError(const NetworkException());

      // Sem erro: o ViewModel descartado não recebe o aviso.
      await expectLater(refresh, completes);
    });
  });
}
