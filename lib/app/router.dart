import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reportaai_cm/app/routes.dart';
import 'package:reportaai_cm/features/health/presentation/views/diagnostics_view.dart';
import 'package:reportaai_cm/features/home/presentation/views/home_view.dart';

/// O router do app, criado uma vez e descartado junto com o `ProviderScope`.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefreshNotifier();
  // No épico de login: ref.listen(authControllerProvider, (_, _) => refresh.notify());
  final router = createRouter(refreshListenable: refresh);

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

/// Monta as rotas. A de diagnóstico só entra em debug: no release, `/diagnostico` não existe.
GoRouter createRouter({
  Listenable? refreshListenable,
  bool enableDiagnostics = kDebugMode,
  String initialLocation = AppRoutes.home,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
    redirect: _redirect,
    // Uma rota que não existe (um deep link antigo, por exemplo) leva à tela inicial.
    onException: (context, state, router) => router.go(AppRoutes.home),
    routes: [
      GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeView()),
      if (enableDiagnostics)
        GoRoute(path: AppRoutes.diagnostics, builder: (context, state) => const DiagnosticsView()),
    ],
  );
}

/// O lugar central que escolhe a tela a partir do estado do app. Nesta sprint não há regra:
/// `null` mantém a rota pedida. No épico de login, ele leva ao login quem não tem sessão, e
/// nenhuma tela navega sozinha depois do login ou do "Sair".
String? _redirect(BuildContext context, GoRouterState state) => null;
