import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

extension AppLifecycle on WidgetTester {
  /// O app vai para o segundo plano e volta, como depois de confirmar o e-mail no navegador. Passa
  /// pelos estados do meio, como no aparelho: o binding de teste não os cria sozinho, e o
  /// `AppLifecycleListener` recusa a troca direta de `paused` para `resumed`. Depois, o teste
  /// desenha a tela.
  void leaveAndComeBack() {
    const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ].forEach(binding.handleAppLifecycleStateChanged);
  }
}
