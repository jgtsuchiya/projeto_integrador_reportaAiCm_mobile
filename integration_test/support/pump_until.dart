import 'package:flutter_test/flutter_test.dart';

extension PumpUntil on WidgetTester {
  /// Desenha a tela até o [finder] achar algo, por até [timeout]. Contra a API de verdade, o
  /// `pumpAndSettle` não basta: ele termina quando a tela para de mudar, e a resposta pode chegar
  /// depois, como no "Sair", que espera a API sem nenhuma animação na tela.
  Future<void> pumpUntilFound(
    Finder finder, {
    String? reason,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (finder.evaluate().isEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        fail('${reason ?? 'A tela não mudou.'}\nEsperado em até ${timeout.inSeconds} s: $finder');
      }
      // No teste de integração, o pump com duração espera o tempo de verdade.
      await pump(const Duration(milliseconds: 100));
    }
  }
}
