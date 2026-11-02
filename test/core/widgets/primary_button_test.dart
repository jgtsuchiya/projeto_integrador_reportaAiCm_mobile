import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/widgets/primary_button.dart';

import '../../support/pump_app.dart';

/// Uma tela de exemplo: o toque começa uma ação demorada e mostra o carregando até ela terminar.
class _SlowAction extends StatefulWidget {
  const new({required this.action});

  final Future<void> Function() action;

  @override
  State<_SlowAction> createState() => _SlowActionState();
}

class _SlowActionState extends State<_SlowAction> {
  bool _isLoading = false;

  Future<void> _run() async {
    setState(() => _isLoading = true);
    await widget.action();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: PrimaryButton(label: 'Entrar', isLoading: _isLoading, onPressed: _run),
    ),
  );
}

void main() {
  group('PrimaryButton', () {
    testWidgets('deve chamar a ação no toque', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        Scaffold(
          body: PrimaryButton(label: 'Entrar', onPressed: () => taps++),
        ),
      );

      await tester.tap(find.text('Entrar'));

      expect(taps, 1);
    });

    testWidgets('deve ignorar o segundo toque enquanto carrega', (tester) async {
      var calls = 0;
      final pending = Completer<void>();
      await tester.pumpApp(
        _SlowAction(
          action: () {
            calls++;
            return pending.future;
          },
        ),
      );

      await tester.tap(find.text('Entrar'));
      await tester.pump();
      await tester.tap(find.text('Entrar'), warnIfMissed: false);
      await tester.pump();

      expect(calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('Entrar'));
      expect(calls, 2);
    });

    testWidgets('deve mostrar o carregando com a cor de ativo e anunciar o "Carregando"', (
      tester,
    ) async {
      await tester.pumpApp(
        const Scaffold(body: PrimaryButton(label: 'Entrar', isLoading: true, onPressed: null)),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final context = tester.element(find.byType(FilledButton));
      final colorScheme = Theme.of(context).colorScheme;

      expect(button.onPressed, isNull);
      expect(button.style?.backgroundColor?.resolve({WidgetState.disabled}), colorScheme.primary);
      // O leitor de tela lê o botão inteiro: o "Carregando" e o rótulo.
      expect(find.bySemanticsLabel(RegExp('Carregando')), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
    });

    testWidgets('deve ter pelo menos 48 dp de altura', (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: Center(
            child: PrimaryButton(label: 'Entrar', onPressed: () {}),
          ),
        ),
      );

      expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48));
    });

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('deve passar nas verificações de acessibilidade (${themeMode.name})', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpApp(
          Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(label: 'Entrar', onPressed: () {}),
                  const PrimaryButton(label: 'Entrando', isLoading: true, onPressed: null),
                ],
              ),
            ),
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
