import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/home/presentation/views/home_view.dart';

import '../../../../support/pump_app.dart';

void main() {
  group('HomeView', () {
    testWidgets('deve mostrar o nome do app', (tester) async {
      await tester.pumpApp(const HomeView());

      expect(find.text('ReportaAi Cm'), findsWidgets);
      expect(find.text('Reporte os buracos no asfalto de Campo Mourão.'), findsOneWidget);
    });

    testWidgets('deve mostrar o atalho do diagnóstico só quando ele existe', (tester) async {
      await tester.pumpApp(const HomeView());

      expect(find.text('Diagnóstico da API'), findsOneWidget);

      await tester.pumpApp(const HomeView(showDiagnostics: false));

      expect(find.text('Diagnóstico da API'), findsNothing);
    });

    testWidgets('deve aguentar a fonte em 200%', (tester) async {
      tester.usePhoneScreen(textScale: 2);

      await tester.pumpApp(const HomeView());

      expect(tester.takeException(), isNull);
    });

    testWidgets('deve passar nas verificações de acessibilidade', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpApp(const HomeView());

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  });
}
