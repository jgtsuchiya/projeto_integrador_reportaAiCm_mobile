import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reportaai_cm/app/router.dart';

import 'auth_fakes.dart';
import 'pump_app.dart';

/// Abre o app inteiro, como o `main`, com os [fakes]. Termina com a tela de abertura desenhada e
/// a conferência da sessão começada: o teste decide quanto esperar por ela.
///
/// Devolve as rotas por onde o app passa, na ordem, a partir da abertura: a lista cresce a cada
/// troca de tela. Com ela, o teste confere o caminho inteiro, inclusive a tela que não pode
/// aparecer, como o login na abertura com a sessão guardada.
Future<List<String>> openWholeApp(WidgetTester tester, AuthFakes fakes) async {
  final history = RouteHistory();
  await tester.pumpWholeApp(overrides: fakes.overrides, observers: [history]);

  return history.routes;
}

/// Guarda as rotas por onde o router do app passa, desde a criação dele. Ouvir o router depois
/// de montar o app perderia a primeira troca: com os fakes, a conferência da sessão termina
/// antes de o `pumpWholeApp` voltar.
///
/// Conta a rota do alto da pilha: uma tela aberta com o `push` (como o cadastro, por cima do
/// login) entra na lista, e a volta para a tela de baixo também.
final class RouteHistory extends ProviderObserver {
  final routes = <String>[];

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    if (value is! GoRouter) return;

    // O `uri` da pilha continua o da tela de baixo depois de um `push`: o `state` do router é o
    // da tela do alto.
    value.routerDelegate.addListener(() {
      final path = value.state.uri.path;
      if (path != routes.lastOrNull) routes.add(path);
    });
  }
}

/// O router do app montado pelo [openWholeApp].
GoRouter appRouter(WidgetTester tester) => tester.container().read(routerProvider);

/// Confere que o "voltar" do Android fecha o app, em vez de voltar para a tela anterior: depois
/// do login, do login automático do cadastro ou do "Sair", o redirect troca a pilha inteira.
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

  expect(appRouter(tester).canPop(), isFalse);

  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();

  expect(platformCalls, contains('SystemNavigator.pop'));
}
