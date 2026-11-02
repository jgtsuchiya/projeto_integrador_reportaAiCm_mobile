import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reportaai_cm/core/widgets/error_view.dart';

import '../../support/pump_app.dart';

/// Um callback não compensa um fake: o mocktail confere a chamada.
class _MockCallback extends Mock {
  void call();
}

void main() {
  group('ErrorView', () {
    const message = 'Não foi possível conectar ao servidor. Confira a sua internet.';

    testWidgets('deve mostrar o título, a mensagem e o "Tentar de novo"', (tester) async {
      final onRetry = _MockCallback();
      await tester.pumpApp(
        Scaffold(
          body: ErrorView(message: message, onRetry: onRetry.call),
        ),
      );

      await tester.tap(find.text('Tentar de novo'));

      expect(find.text('Algo deu errado'), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      verify(onRetry.call).called(1);
    });

    testWidgets('não deve mostrar o "Tentar de novo" sem a ação', (tester) async {
      await tester.pumpApp(
        const Scaffold(
          body: ErrorView(title: 'Sem acesso', message: message),
        ),
      );

      expect(find.text('Sem acesso'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsNothing);
    });

    testWidgets('deve rolar, sem cortar o texto, com a fonte em 200%', (tester) async {
      tester.usePhoneScreen(textScale: 2);
      await tester.pumpApp(
        Scaffold(
          body: ErrorView(message: List.filled(8, message).join(' '), onRetry: () {}),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Tentar de novo'), 100);

      expect(find.text('Tentar de novo').hitTestable(), findsOneWidget);
    });

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('deve passar nas verificações de acessibilidade (${themeMode.name})', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpApp(
          Scaffold(
            body: ErrorView(message: message, onRetry: () {}),
          ),
          themeMode: themeMode,
        );

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      });
    }
  });
}
