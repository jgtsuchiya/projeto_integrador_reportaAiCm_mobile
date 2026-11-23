import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/features/auth/presentation/widgets/password_rules.dart';

import '../../../../support/pump_app.dart';

void main() {
  group('PasswordRules', () {
    late TextEditingController password;

    setUp(() => password = TextEditingController());
    tearDown(() => password.dispose());

    Future<void> pumpRules(WidgetTester tester, {ThemeMode themeMode = ThemeMode.light}) =>
        tester.pumpApp(
          Scaffold(body: PasswordRules(password: password)),
          themeMode: themeMode,
        );

    Finder ruleWithState(String label, {required bool isMet}) =>
        find.bySemanticsLabel('$label: ${isMet ? 'cumprido' : 'ainda não cumprido'}');

    testWidgets('deve mostrar cada item da política de senha (RN08)', (tester) async {
      await pumpRules(tester);

      expect(find.text('A senha precisa ter:'), findsOneWidget);
      for (final label in [
        'De 8 a 128 caracteres',
        'Pelo menos uma letra',
        'Pelo menos um número',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('deve marcar os itens cumpridos enquanto a senha é digitada', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpRules(tester);

      expect(ruleWithState('Pelo menos uma letra', isMet: false), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);

      password.text = 'abc';
      await tester.pump();

      expect(ruleWithState('Pelo menos uma letra', isMet: true), findsOneWidget);
      expect(ruleWithState('Pelo menos um número', isMet: false), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      password.text = 'senha-forte-1';
      await tester.pump();

      expect(ruleWithState('De 8 a 128 caracteres', isMet: true), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
      semantics.dispose();
    });

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        'deve ter o contraste do texto, com e sem os itens cumpridos (${themeMode.name})',
        (tester) async {
          final semantics = tester.ensureSemantics();
          password.text = 'abc';
          await pumpRules(tester, themeMode: themeMode);

          await expectLater(tester, meetsGuideline(textContrastGuideline));
          semantics.dispose();
        },
      );
    }
  });
}
