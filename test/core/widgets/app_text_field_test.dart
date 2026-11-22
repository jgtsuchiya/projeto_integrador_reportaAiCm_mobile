import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/widgets/app_text_field.dart';

import '../../support/pump_app.dart';

void main() {
  group('AppTextField', () {
    Future<void> pumpField(WidgetTester tester, Widget field, {ThemeMode? themeMode}) {
      return tester.pumpApp(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(child: field),
          ),
        ),
        themeMode: themeMode ?? ThemeMode.light,
      );
    }

    testWidgets('deve mostrar o rótulo e repassar o texto digitado', (tester) async {
      String? typed;
      await pumpField(tester, AppTextField(label: 'E-mail', onChanged: (value) => typed = value));

      await tester.enterText(find.byType(TextFormField), 'maria@example.com');

      expect(find.text('E-mail'), findsOneWidget);
      expect(typed, 'maria@example.com');
    });

    testWidgets('deve mostrar a mensagem de erro de fora, como a da API', (tester) async {
      await pumpField(tester, const AppTextField(label: 'CPF', errorText: 'CPF já cadastrado.'));

      expect(find.text('CPF já cadastrado.'), findsOneWidget);
    });

    testWidgets('deve mostrar o erro da validação local quando o formulário é conferido', (
      tester,
    ) async {
      await pumpField(
        tester,
        AppTextField(
          label: 'E-mail',
          validator: (value) => (value ?? '').isEmpty ? 'Informe o e-mail.' : null,
        ),
      );

      tester.state<FormState>(find.byType(Form)).validate();
      await tester.pump();

      expect(find.text('Informe o e-mail.'), findsOneWidget);
    });

    testWidgets('deve ocultar o texto e desligar a correção no campo de senha', (tester) async {
      await pumpField(tester, const AppTextField(label: 'Senha', obscureText: true));

      final field = tester.widget<TextField>(find.byType(TextField));

      expect(field.obscureText, isTrue);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.enableIMEPersonalizedLearning, isFalse);
    });

    testWidgets('deve desligar as sugestões e o aprendizado do teclado no campo visível', (
      tester,
    ) async {
      await pumpField(tester, const AppTextField(label: 'Senha', enableSuggestions: false));

      final field = tester.widget<TextField>(find.byType(TextField));

      expect(field.obscureText, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.enableIMEPersonalizedLearning, isFalse);
    });

    testWidgets('deve manter as sugestões e o aprendizado do teclado por padrão', (tester) async {
      await pumpField(tester, const AppTextField(label: 'Nome'));

      final field = tester.widget<TextField>(find.byType(TextField));

      expect(field.enableSuggestions, isTrue);
      expect(field.enableIMEPersonalizedLearning, isTrue);
    });

    testWidgets('deve quebrar a mensagem de erro longa com a fonte em 200%', (tester) async {
      tester.usePhoneScreen(textScale: 2);
      await pumpField(
        tester,
        const AppTextField(
          label: 'Senha',
          errorText:
              'A senha deve ter de 8 a 128 caracteres, com pelo menos uma letra e um número.',
        ),
      );

      expect(tester.takeException(), isNull);
    });

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('deve passar nas verificações de acessibilidade (${themeMode.name})', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpField(
          tester,
          const AppTextField(label: 'E-mail', errorText: 'Formato de e-mail inválido.'),
          themeMode: themeMode,
        );

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      });
    }
  });
}
