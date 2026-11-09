import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/router.dart';
import 'package:reportaai_cm/app/routes.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/views/login_view.dart';
import 'package:reportaai_cm/features/auth/presentation/views/splash_view.dart';
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
    ]) {
      test('deve levar de $path para ${expected ?? 'a mesma rota'} com o $state', () {
        expect(redirectFor(state, path), expected);
      });
    }

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

  group('Navegação pelo estado de login', () {
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

    /// Confere que o "voltar" do Android fecha o app, em vez de voltar para outra tela.
    Future<void> expectBackClosesTheApp(WidgetTester tester) async {
      final platformCalls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
        call,
      ) async {
        platformCalls.add(call.method);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      expect(router(tester).canPop(), isFalse);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(platformCalls, contains('SystemNavigator.pop'));
    }

    testWidgets('deve abrir na tela de abertura e ir para o login sem sessão', (tester) async {
      await tester.pumpWholeApp(overrides: fakes.overrides);

      expect(find.byType(SplashView), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(LoginView), findsOneWidget);
      expect(router(tester).state.uri.path, AppRoutes.login);
    });

    testWidgets('deve abrir direto na tela inicial com a sessão guardada (RM06)', (tester) async {
      fakes.session.hasStoredSession = true;

      await openApp(tester);

      expect(find.byType(HomeView), findsOneWidget);
      expect(find.byType(LoginView), findsNothing);
      await expectBackClosesTheApp(tester);
    });

    testWidgets('deve mostrar o erro sem rede e entrar no "Tentar de novo" (RM06)', (tester) async {
      fakes.session.hasStoredSession = true;
      fakes.profile.error = const NetworkException();
      await openApp(tester);
      expect(find.byType(SplashView), findsOneWidget);
      expect(find.text(NetworkException.defaultMessage), findsOneWidget);
      fakes.profile.error = null;

      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeView), findsOneWidget);
    });

    testWidgets('deve ir para a tela inicial depois do login, e o "voltar" fecha o app', (
      tester,
    ) async {
      await openApp(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), clientProfile.email);
      await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'SenhaSecreta123');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeView), findsOneWidget);
      expect(find.text(clientProfile.name), findsOneWidget);
      await expectBackClosesTheApp(tester);
    });

    testWidgets('deve continuar no login, com o aviso, no login de um ADMIN (RM01)', (
      tester,
    ) async {
      fakes.profile.result = adminProfile;
      await openApp(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), adminProfile.email);
      await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'SenhaSecreta123');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginView), findsOneWidget);
      expect(find.text(UnauthenticatedReason.roleNotAllowed.message), findsOneWidget);
    });

    testWidgets('deve voltar ao login com o aviso quando a sessão acaba (RM07)', (tester) async {
      fakes.session.hasStoredSession = true;
      await openApp(tester);

      fakes.session.expire();
      await tester.pumpAndSettle();

      expect(find.byType(LoginView), findsOneWidget);
      expect(find.text(UnauthenticatedReason.sessionExpired.message), findsOneWidget);
    });

    testWidgets('deve voltar ao login sem aviso pelo "Sair", e o "voltar" fecha o app', (
      tester,
    ) async {
      fakes.session.hasStoredSession = true;
      await openApp(tester);

      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginView), findsOneWidget);
      expect(find.text(UnauthenticatedReason.sessionExpired.message), findsNothing);
      await expectBackClosesTheApp(tester);
    });

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
