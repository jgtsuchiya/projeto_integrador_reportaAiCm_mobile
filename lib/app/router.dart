import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reportaai_cm/app/routes.dart';
import 'package:reportaai_cm/features/account/presentation/views/account_view.dart';
import 'package:reportaai_cm/features/account/presentation/views/change_password_view.dart';
import 'package:reportaai_cm/features/account/presentation/views/delete_account_view.dart';
import 'package:reportaai_cm/features/account/presentation/views/edit_profile_view.dart';
import 'package:reportaai_cm/features/account/presentation/views/second_factor_settings_view.dart';
import 'package:reportaai_cm/features/account/presentation/views/sessions_view.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/views/forgot_password_view.dart';
import 'package:reportaai_cm/features/auth/presentation/views/login_view.dart';
import 'package:reportaai_cm/features/auth/presentation/views/registration_view.dart';
import 'package:reportaai_cm/features/auth/presentation/views/second_factor_view.dart';
import 'package:reportaai_cm/features/auth/presentation/views/splash_view.dart';
import 'package:reportaai_cm/features/health/presentation/views/diagnostics_view.dart';
import 'package:reportaai_cm/features/home/presentation/views/home_view.dart';
import 'package:reportaai_cm/features/reports/presentation/views/edit_report_view.dart';
import 'package:reportaai_cm/features/reports/presentation/views/my_reports_view.dart';
import 'package:reportaai_cm/features/reports/presentation/views/nearby_reports_view.dart';
import 'package:reportaai_cm/features/reports/presentation/views/new_report_view.dart';
import 'package:reportaai_cm/features/reports/presentation/views/report_detail_view.dart';

/// O router do app, criado uma vez e descartado junto com o `ProviderScope`. Ele ouve o
/// `authControllerProvider`: quando o tipo do estado de login muda, o redirect escolhe a tela de
/// novo ([changesRoute]).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefreshNotifier();
  ref.listen(authControllerProvider, (previous, next) {
    if (changesRoute(previous, next)) refresh.notify();
  });
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

/// Se a mudança do estado de login de [previous] para [next] pode mudar a tela: o [redirectFor]
/// só depende do tipo do estado. O perfil novo depois de salvar os dados, ou o motivo que sai do
/// login, não reavaliam o redirect.
///
/// Reavaliar à toa não é inofensivo: o go_router reconstrói a pilha a partir da última rota que
/// conhece, e uma tela que acabou de fechar com o `pop` (como a "Editar dados", depois de salvar)
/// voltaria a abrir.
bool changesRoute(AuthState? previous, AuthState next) => previous?.runtimeType != next.runtimeType;

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
      GoRoute(path: AppRoutes.register, builder: (context, state) => const RegistrationView()),
      GoRoute(
        path: AppRoutes.forgotPassword,
        // O login manda o e-mail que já estava digitado.
        builder: (context, state) => ForgotPasswordView(
          initialEmail: switch (state.extra) {
            final String email => email,
            _ => '',
          },
        ),
      ),
      GoRoute(path: AppRoutes.secondFactor, builder: (context, state) => const SecondFactorView()),
      GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeView()),
      // As telas da conta ficam embaixo da `/conta`: um deep link para uma delas abre com a
      // `/conta` atrás, e o "voltar" volta para ela.
      GoRoute(
        path: AppRoutes.account,
        builder: (context, state) => const AccountView(),
        routes: [
          GoRoute(path: 'dados', builder: (context, state) => const EditProfileView()),
          GoRoute(path: 'senha', builder: (context, state) => const ChangePasswordView()),
          GoRoute(path: 'sessoes', builder: (context, state) => const SessionsView()),
          GoRoute(
            path: 'verificacao',
            builder: (context, state) => const SecondFactorSettingsView(),
          ),
          GoRoute(path: 'excluir', builder: (context, state) => const DeleteAccountView()),
        ],
      ),
      // As telas dos reportes ficam embaixo da `/reportes`, como as da conta. O `novo` e o
      // `perto` vêm antes do `:id`, para não serem lidos como um id.
      GoRoute(
        path: AppRoutes.reports,
        builder: (context, state) => const MyReportsView(),
        routes: [
          GoRoute(path: 'novo', builder: (context, state) => const NewReportView()),
          GoRoute(path: 'perto', builder: (context, state) => const NearbyReportsView()),
          GoRoute(
            path: ':id',
            // A distância vem da busca dos reportes perto: a lista deles e o aviso do reporte
            // repetido.
            builder: (context, state) => ReportDetailView(
              reportId: state.pathParameters['id']!,
              distanceMeters: switch (state.extra) {
                final int meters => meters,
                _ => null,
              },
            ),
            routes: [
              GoRoute(
                path: 'editar',
                builder: (context, state) => EditReportView(reportId: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),
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
/// - `AuthChecking` e `AuthLoadFailed`: a abertura, também para as rotas públicas;
/// - `AuthUnauthenticated`: o login, ou a rota pública pedida (o cadastro e o "Esqueci minha
///   senha"). Nenhuma rota autenticada abre sem sessão;
/// - `AuthSecondFactorPending`: a tela do código, em qualquer rota (RM18);
/// - `AuthAuthenticated`: a rota pedida, menos a abertura, o login, a tela do código e as rotas
///   públicas, que levam à tela inicial. Assim, o login automático do cadastro troca a pilha
///   inteira, e o "voltar" não volta ao cadastro.
///
/// O diagnóstico (só em debug) abre em qualquer estado: ele confere a API antes do login.
String? redirectFor(AuthState auth, String path) {
  if (path == AppRoutes.diagnostics) return null;

  final isPublic = AppRoutes.public.contains(path);
  final target = switch (auth) {
    AuthChecking() || AuthLoadFailed() => AppRoutes.splash,
    AuthUnauthenticated() when isPublic => path,
    AuthUnauthenticated() => AppRoutes.login,
    AuthSecondFactorPending() => AppRoutes.secondFactor,
    AuthAuthenticated() when isPublic || _signedOutRoutes.contains(path) => AppRoutes.home,
    AuthAuthenticated() => path,
  };

  return target == path ? null : target;
}

/// As rotas de antes da entrada, que o Client dentro não vê mais: levam à tela inicial.
const Set<String> _signedOutRoutes = {AppRoutes.splash, AppRoutes.login, AppRoutes.secondFactor};
