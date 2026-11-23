import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:reportaai_cm/core/auth/session_manager_provider.dart';
import 'package:reportaai_cm/features/account/account_providers.dart';
import 'package:reportaai_cm/features/auth/auth_providers.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/profile/profile_providers.dart';

import 'fake_auth_repository.dart';
import 'fake_profile_repository.dart';
import 'fake_registration_repository.dart';
import 'fake_session_manager.dart';
import 'fake_sessions_repository.dart';

/// Os fakes do login e da conta ligados entre si, como no app: a sessão do [auth] é o [session], que o
/// `AuthController` também ouve. Os [overrides] os colocam no `ProviderScope`:
///
/// ```dart
/// final fakes = AuthFakes(signedIn: true);
/// await tester.pumpWholeApp(overrides: fakes.overrides);
/// ```
final class AuthFakes {
  /// Com [signedIn], já há uma sessão guardada no aparelho: o app abre direto na tela inicial,
  /// com o perfil do [profile] (o Client do exemplo, se o teste não trocar).
  new({bool signedIn = false}) {
    session.hasStoredSession = signedIn;
  }

  final session = FakeSessionManager();
  late final auth = FakeAuthRepository(session: session);
  final profile = FakeProfileRepository();

  /// O cadastro do Client. Com o cadastro feito, o login automático passa pelo [auth].
  final registration = FakeRegistrationRepository();

  /// As sessões abertas da conta, da tela "Sessões abertas".
  final sessions = FakeSessionsRepository();

  /// Para o `beforePush` do `pumpPushed`: cria o `AuthController`, que confere a sessão antes de a
  /// tela abrir, como o router do app.
  static void startAuth(ProviderContainer container) => container.read(authControllerProvider);

  List<Override> get overrides => [
    sessionManagerProvider.overrideWithValue(session),
    authRepositoryProvider.overrideWithValue(auth),
    profileRepositoryProvider.overrideWithValue(profile),
    registrationRepositoryProvider.overrideWithValue(registration),
    sessionsRepositoryProvider.overrideWithValue(sessions),
  ];
}
