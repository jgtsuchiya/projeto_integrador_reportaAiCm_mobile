import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reportaai_cm/app/routes.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/views/login_view.dart';
import 'package:reportaai_cm/features/auth/presentation/views/splash_view.dart';
import 'package:reportaai_cm/features/health/presentation/views/diagnostics_view.dart';
import 'package:reportaai_cm/features/home/presentation/views/home_view.dart';

/// O router do app, criado uma vez e descartado junto com o `ProviderScope`. Ele ouve o
/// `authControllerProvider`: a cada mudança do estado de login, o redirect escolhe a tela de novo.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefreshNotifier();
  ref.listen(authControllerProvider, (_, _) => refresh.notify());
  final router = createRouter(
    authState: () => ref.read(authControllerProvider),
    refreshListenable: refresh,
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });

  return router;
});

/// Avisa o go_router para reavaliar o redirect, quando o estado de que ele depende muda.
final class RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Monta as rotas, com o redirect a partir do [authState]. A rota de diagnóstico só entra em
/// debug: no release, `/diagnostico` não existe.
GoRouter createRouter({
  required AuthState Function() authState,
  Listenable? refreshListenable,
  bool enableDiagnostics = kDebugMode,
  String initialLocation = AppRoutes.splash,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
    redirect: (context, state) => redirectFor(authState(), state.uri.path),
    // Uma rota que não existe (um deep link antigo, por exemplo) leva à tela inicial, ou ao login
    // pelo redirect, para quem não entrou.
    onException: (context, state, router) => router.go(AppRoutes.home),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashView()),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginView()),
      GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeView()),
      if (enableDiagnostics)
        GoRoute(path: AppRoutes.diagnostics, builder: (context, state) => const DiagnosticsView()),
    ],
  );
}

/// O lugar central que escolhe a tela a partir do estado de login: devolve a rota para onde ir, ou
/// `null` para ficar no [path]. Nenhuma tela navega sozinha depois do login ou do "Sair": elas
/// mudam o estado, e o redirect leva à tela certa, trocando a pilha inteira. Por isso, o "voltar"
/// do Android na tela inicial fecha o app, sem voltar ao login.
///
/// - `AuthChecking` e `AuthLoadFailed`: a abertura;
/// - `AuthUnauthenticated`: o login. Nenhuma rota autenticada abre sem sessão;
/// - `AuthAuthenticated`: a rota pedida, menos a abertura e o login, que levam à tela inicial.
///
/// O diagnóstico (só em debug) abre em qualquer estado: ele confere a API antes do login.
String? redirectFor(AuthState auth, String path) {
  if (path == AppRoutes.diagnostics) return null;

  final target = switch (auth) {
    AuthChecking() || AuthLoadFailed() => AppRoutes.splash,
    AuthUnauthenticated() => AppRoutes.login,
    AuthAuthenticated() when path == AppRoutes.splash || path == AppRoutes.login => AppRoutes.home,
    AuthAuthenticated() => path,
  };

  return target == path ? null : target;
}
