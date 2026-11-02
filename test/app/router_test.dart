import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/router.dart';
import 'package:reportaai_cm/app/routes.dart';
import 'package:reportaai_cm/features/health/health_providers.dart';
import 'package:reportaai_cm/features/health/presentation/views/diagnostics_view.dart';
import 'package:reportaai_cm/features/home/presentation/views/home_view.dart';

import '../support/fake_health_repository.dart';
import '../support/pump_app.dart';

void main() {
  group('createRouter', () {
    Future<GoRouter> pumpRouter(WidgetTester tester, {bool enableDiagnostics = true}) async {
      final router = createRouter(enableDiagnostics: enableDiagnostics);
      addTearDown(router.dispose);
      await tester.pumpRouter(
        router,
        overrides: [healthRepositoryProvider.overrideWithValue(FakeHealthRepository())],
      );
      return router;
    }

    testWidgets('deve abrir na tela inicial', (tester) async {
      await pumpRouter(tester);

      expect(find.byType(HomeView), findsOneWidget);
    });

    testWidgets('deve abrir o diagnóstico pelo atalho e voltar para o início', (tester) async {
      await pumpRouter(tester);

      await tester.tap(find.text('Diagnóstico da API'));
      await tester.pumpAndSettle();

      expect(find.byType(DiagnosticsView), findsOneWidget);
      expect(find.text('ok'), findsOneWidget);

      // O pageBack() do flutter_test procura o BackButton do flutter/material, não o do
      // material_ui: o toque vai direto no botão.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(HomeView), findsOneWidget);
    });

    testWidgets('não deve ter a rota de diagnóstico fora do debug', (tester) async {
      final router = await pumpRouter(tester, enableDiagnostics: false);

      router.go(AppRoutes.diagnostics);
      await tester.pumpAndSettle();

      expect(find.byType(DiagnosticsView), findsNothing);
      expect(find.byType(HomeView), findsOneWidget);
    });

    testWidgets('deve levar uma rota que não existe para a tela inicial', (tester) async {
      final router = await pumpRouter(tester);

      router.go('/rota-que-nao-existe');
      await tester.pumpAndSettle();

      expect(find.byType(HomeView), findsOneWidget);
      expect(router.state.uri.path, AppRoutes.home);
    });

    testWidgets('deve reavaliar o redirect quando o refreshListenable avisa', (tester) async {
      final refresh = RouterRefreshNotifier();
      addTearDown(refresh.dispose);
      final router = createRouter(refreshListenable: refresh);
      addTearDown(router.dispose);
      await tester.pumpRouter(router);

      refresh.notify();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(HomeView), findsOneWidget);
    });
  });

  group('routerProvider', () {
    test('deve criar um router único, aberto na tela inicial', () {
      final container = ProviderContainer.test();

      final sut = container.read(routerProvider);

      expect(sut.routeInformationProvider.value.uri.path, AppRoutes.home);
      expect(container.read(routerProvider), same(sut));
    });
  });
}
