import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';

import '../../support/pump_app.dart';

void main() {
  group('ScrollableCenter', () {
    testWidgets('deve centralizar o conteúdo que cabe na tela', (tester) async {
      tester.usePhoneScreen();
      const content = Key('conteúdo');
      await tester.pumpApp(
        const Scaffold(
          body: ScrollableCenter(child: SizedBox.square(key: content, dimension: 100)),
        ),
      );

      final center = tester.getCenter(find.byKey(content));

      expect(center.dx, closeTo(180, 0.5));
      expect(center.dy, closeTo(320, 0.5));
    });

    testWidgets('deve rolar o conteúdo maior que a tela', (tester) async {
      tester.usePhoneScreen();
      await tester.pumpApp(
        const Scaffold(
          body: ScrollableCenter(child: Column(children: [SizedBox(height: 2000), Text('fim')])),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('fim').hitTestable(), findsNothing);

      await tester.scrollUntilVisible(find.text('fim'), 500);

      expect(find.text('fim').hitTestable(), findsOneWidget);
    });

    testWidgets('não deve criar outra rolagem dentro de algo que já rola', (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: ListView(children: const [ScrollableCenter(child: Text('conteúdo'))]),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsOneWidget);
      expect(find.text('conteúdo'), findsOneWidget);
    });
  });
}
