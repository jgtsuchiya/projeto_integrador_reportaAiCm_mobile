import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/router.dart';
import 'package:reportaai_cm/app/routes.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/views/forgot_password_view.dart';
import 'package:reportaai_cm/features/auth/presentation/views/login_view.dart';
import 'package:reportaai_cm/features/auth/presentation/views/registration_view.dart';
import 'package:reportaai_cm/features/health/health_providers.dart';
import 'package:reportaai_cm/features/health/presentation/views/diagnostics_view.dart';
import 'package:reportaai_cm/features/home/presentation/views/home_view.dart';

import '../support/auth_fakes.dart';
import '../support/fake_health_repository.dart';
import '../support/fake_profile_repository.dart';
import '../support/pump_app.dart';

void main() {
  group('redirectFor', () {
    final authenticated = AuthAuthenticated(clientProfile);
    const checking = AuthChecking();
    const loadFailed = AuthLoadFailed(NetworkException());
    const unauthenticated = AuthUnauthenticated();

    for (final (state, path, expected) in [
      (checking, AppRoutes.splash, null),
      (checking, AppRoutes.login, AppRoutes.splash),
      (checking, AppRoutes.home, AppRoutes.splash),
      (loadFailed, AppRoutes.splash, null),
      (loadFailed, AppRoutes.home, AppRoutes.splash),
      (unauthenticated, AppRoutes.login, null),
      (unauthenticated, AppRoutes.splash, AppRoutes.login),
      (unauthenticated, AppRoutes.home, AppRoutes.login),
      (unauthenticated, '/reportes', AppRoutes.login),
      (authenticated, AppRoutes.home, null),
      (authenticated, AppRoutes.splash, AppRoutes.home),
      (authenticated, AppRoutes.login, AppRoutes.home),
      // Uma rota autenticada nova, como a dos reportes, abre sem mudar o redirect.
      (authenticated, '/reportes', null),
      // As rotas públicas abrem sem sessão e levam à tela inicial com o Client dentro. Assim, o
      // login automático do cadastro troca a pilha, e o "voltar" não volta ao cadastro.
      for (final path in [AppRoutes.register, AppRoutes.forgotPassword]) ...[
        (unauthenticated, path, null),
        (const AuthUnauthenticated(reason: UnauthenticatedReason.sessionExpired), path, null),
        (checking, path, AppRoutes.splash),
        (loadFailed, path, AppRoutes.splash),
        (authenticated, path, AppRoutes.home),
      ],
    ]) {
      test('deve levar de $path para ${expected ?? 'a mesma rota'} com o $state', () {
        expect(redirectFor(state, path), expected);
      });
    }

    test('deve ter só o cadastro e o "Esqueci minha senha" como rotas públicas', () {
      expect(AppRoutes.public, {'/cadastro', '/esqueci-senha'});
    });

    test('deve abrir o diagnóstico em qualquer estado', () {
      for (final state in [checking, loadFailed, unauthenticated, authenticated]) {
        expect(redirectFor(state, AppRoutes.diagnostics), isNull, reason: '$state');
      }
    });
  });

  group('createRouter', () {
    testWidgets('deve escolher a tela de novo quando o refreshListenable avisa', (tester) async {
      AuthState auth = const AuthUnauthenticated();
      final refresh = RouterRefreshNotifier();
      addTearDown(refresh.dispose);
      final router = createRouter(authState: () => auth, refreshListenable: refresh);
      addTearDown(router.dispose);
      await tester.pumpRouter(router, overrides: AuthFakes().overrides);
      await tester.pumpAndSettle();
      expect(find.byType(LoginView), findsOneWidget);

      auth = AuthAuthenticated(clientProfile);
      refresh.notify();
      await tester.pumpAndSettle();

      expect(find.byType(HomeView), findsOneWidget);
      expect(router.state.uri.path, AppRoutes.home);
    });

    testWidgets('não deve ter a rota de diagnóstico fora do debug', (tester) async {
      final router = createRouter(
        authState: () => const AuthUnauthenticated(),
        enableDiagnostics: false,
      );
      addTearDown(router.dispose);
      await tester.pumpRouter(router, overrides: AuthFakes().overrides);

      router.go(AppRoutes.diagnostics);
      await tester.pumpAndSettle();

      expect(find.byType(DiagnosticsView), findsNothing);
      expect(find.byType(LoginView), findsOneWidget);
    });
  });

  group('routerProvider', () {
    test('deve criar um router único, aberto na tela de abertura', () {
      final container = ProviderContainer.test(overrides: AuthFakes().overrides);

      final sut = container.read(routerProvider);

      expect(sut.routeInformationProvider.value.uri.path, AppRoutes.splash);
      expect(container.read(routerProvider), same(sut));
    });
  });

  group('Rotas no app inteiro', () {
    late AuthFakes fakes;

    setUp(() => fakes = AuthFakes());

    /// Abre o app inteiro e espera a conferência da sessão e a troca de tela.
    Future<void> openApp(WidgetTester tester) async {
      await tester.pumpWholeApp(
        overrides: [
          ...fakes.overrides,
          healthRepositoryProvider.overrideWithValue(FakeHealthRepository()),
        ],
      );
      await tester.pumpAndSettle();
    }

    GoRouter router(WidgetTester tester) => tester.container().read(routerProvider);

    testWidgets('não deve abrir a tela inicial sem sessão', (tester) async {
      await openApp(tester);

      router(tester).go(AppRoutes.home);
      await tester.pumpAndSettle();

      expect(find.byType(HomeView), findsNothing);
      expect(find.byType(LoginView), findsOneWidget);
    });

    for (final (signedIn, screen) in [(false, LoginView), (true, HomeView)]) {
      testWidgets('deve levar uma rota que não existe para a $screen', (tester) async {
        fakes.session.hasStoredSession = signedIn;
        await openApp(tester);

        router(tester).go('/rota-que-nao-existe');
        await tester.pumpAndSettle();

        expect(find.byType(screen), findsOneWidget);
      });
    }

    for (final (link, screen) in [
      ('Criar conta', RegistrationView),
      ('Esqueci minha senha', ForgotPasswordView),
    ]) {
      testWidgets('deve abrir a $screen pelo "$link" do login e voltar ao login', (tester) async {
        await openApp(tester);

        await tester.tap(find.text(link));
        await tester.pumpAndSettle();

        expect(find.byType(screen), findsOneWidget);
        expect(router(tester).canPop(), isTrue);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byType(LoginView), findsOneWidget);
      });
    }

    testWidgets('deve levar ao "Esqueci minha senha" o e-mail digitado no login', (tester) async {
      await openApp(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), ' maria@exemplo.com ');

      await tester.tap(find.text('Esqueci minha senha'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<ForgotPasswordView>(find.byType(ForgotPasswordView)).initialEmail,
        'maria@exemplo.com',
      );
    });

    for (final (path, screen) in [
      (AppRoutes.register, RegistrationView),
      (AppRoutes.forgotPassword, ForgotPasswordView),
    ]) {
      testWidgets('deve abrir a rota pública $path sem sessão e levar à tela inicial com ela', (
        tester,
      ) async {
        await openApp(tester);

        router(tester).go(path);
        await tester.pumpAndSettle();

        expect(find.byType(screen), findsOneWidget);

        // A sessão aberta por fora da tela, como o login automático do cadastro.
        fakes.session.hasStoredSession = true;
        await tester.container().read(authControllerProvider.notifier).retry();
        await tester.pumpAndSettle();

        expect(find.byType(HomeView), findsOneWidget);
        expect(find.byType(screen), findsNothing);
      });
    }

    testWidgets('deve abrir o diagnóstico pelo atalho do login e voltar', (tester) async {
      await openApp(tester);

      await tester.tap(find.text('Diagnóstico da API'));
      await tester.pumpAndSettle();

      expect(find.byType(DiagnosticsView), findsOneWidget);
      expect(find.text('ok'), findsOneWidget);

      // O pageBack() do flutter_test procura o BackButton do flutter/material, não o do
      // material_ui: o toque vai direto no botão.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(LoginView), findsOneWidget);
    });
  });
}
