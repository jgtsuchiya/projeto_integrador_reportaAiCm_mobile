import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/widgets/loading_indicator.dart';

import '../../support/pump_app.dart';

void main() {
  group('LoadingIndicator', () {
    testWidgets('deve anunciar o "Carregando" quando não há mensagem', (tester) async {
      await tester.pumpApp(const Scaffold(body: LoadingIndicator()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Carregando'), findsOneWidget);
    });

    testWidgets('deve mostrar a mensagem, sem repetir o "Carregando"', (tester) async {
      await tester.pumpApp(const Scaffold(body: LoadingIndicator(message: 'Conferindo a API...')));

      expect(find.text('Conferindo a API...'), findsOneWidget);
      expect(find.bySemanticsLabel('Carregando'), findsNothing);
    });

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('deve passar na verificação de contraste (${themeMode.name})', (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpApp(
          const Scaffold(body: LoadingIndicator(message: 'Conferindo a API...')),
          themeMode: themeMode,
        );

        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      });
    }
  });
}
