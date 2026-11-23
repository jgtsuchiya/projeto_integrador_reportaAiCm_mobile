import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/presentation/view_models/forgot_password_view_model.dart';
import 'package:reportaai_cm/features/auth/presentation/views/forgot_password_view.dart';
import 'package:reportaai_cm/features/auth/presentation/views/login_view.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/pump_app.dart';

const _email = 'maria.silva@exemplo.com';

final Finder _emailField = find.widgetWithText(TextFormField, 'E-mail');
final Finder _sentMessage = find.text(ForgotPasswordViewModel.sentMessage);

void main() {
  group('ForgotPasswordView', () {
    late AuthFakes fakes;

    setUp(() => fakes = AuthFakes());

    Future<void> pumpView(
      WidgetTester tester, {
      String initialEmail = _email,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      await tester.pumpApp(
        ForgotPasswordView(initialEmail: initialEmail),
        overrides: fakes.overrides,
        themeMode: themeMode,
      );
      await tester.pump();
    }

    Future<void> send(WidgetTester tester) async {
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
    }

    String textOf(WidgetTester tester, Finder field) => tester
        .widget<EditableText>(find.descendant(of: field, matching: find.byType(EditableText)))
        .controller
        .text;

    FilledButton button(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byType(FilledButton));

    testWidgets('deve abrir com o e-mail que veio do login e explicar o link', (tester) async {
      await pumpView(tester);

      expect(textOf(tester, _emailField), _email);
      expect(find.text('Enviar link'), findsOneWidget);
      expect(find.textContaining('O link abre no navegador'), findsOneWidget);
      expect(find.textContaining('volte ao app'), findsOneWidget);
      expect(find.text('Voltar ao login'), findsNothing);
    });

    testWidgets('deve mostrar a mensagem do envio e o "Enviar de novo" com a contagem (RM13)', (
      tester,
    ) async {
      await pumpView(tester);

      await send(tester);

      expect(fakes.auth.passwordResetCalls, [_email]);
      expect(_sentMessage, findsOneWidget);
      expect(find.text('Enviar de novo em 60 s'), findsOneWidget);
      expect(button(tester).onPressed, isNull);
      expect(find.text('Voltar ao login'), findsOneWidget);

      await tester.pump(const Duration(seconds: 59));
      expect(find.text('Enviar de novo em 1 s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Enviar de novo'), findsOneWidget);
      expect(button(tester).onPressed, isNotNull);
      expect(_sentMessage, findsOneWidget);
    });

    testWidgets('deve mostrar a mesma mensagem com e sem conta (RN20)', (tester) async {
      // O fake responde como a API: o mesmo 204 para qualquer e-mail.
      await pumpView(tester, initialEmail: 'sem.conta@exemplo.com');
      await send(tester);

      expect(_sentMessage, findsOneWidget);
      await tester.pump(const Duration(minutes: 1));
    });

    testWidgets('deve pedir o link pelo "concluir" do teclado', (tester) async {
      await pumpView(tester);
      await tester.showKeyboard(_emailField);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(fakes.auth.passwordResetCalls, hasLength(1));
      await tester.pump(const Duration(minutes: 1));
    });

    testWidgets('deve recusar o e-mail fora do formato, sem chamar a API', (tester) async {
      await pumpView(tester, initialEmail: 'maria@exemplo');

      await send(tester);

      expect(
        find.descendant(of: _emailField, matching: find.text('E-mail inválido.')),
        findsOneWidget,
      );
      expect(fakes.auth.passwordResetCalls, isEmpty);
    });

    testWidgets('deve mostrar o 400 da API no campo do e-mail', (tester) async {
      fakes.auth.passwordResetError = const ValidationException(
        fieldErrors: [FieldError(field: 'email', message: 'E-mail inválido.')],
      );
      await pumpView(tester);

      await send(tester);

      expect(
        find.descendant(of: _emailField, matching: find.text('E-mail inválido.')),
        findsOneWidget,
      );
      expect(_sentMessage, findsNothing);
    });

    testWidgets('deve desativar o botão com a contagem do 429 e voltar sozinho', (tester) async {
      fakes.auth.passwordResetError = const RateLimitException(retryAfter: Duration(seconds: 2));
      await pumpView(tester);

      await send(tester);

      expect(find.text('Muitas tentativas. Tente de novo em 2 s.'), findsOneWidget);
      expect(button(tester).onPressed, isNull);

      await tester.pump(const Duration(seconds: 2));

      expect(find.textContaining('Muitas tentativas'), findsNothing);
      expect(button(tester).onPressed, isNotNull);
    });

    testWidgets('deve mostrar a mensagem sem conexão', (tester) async {
      fakes.auth.passwordResetError = const NetworkException();
      await pumpView(tester);

      await send(tester);

      expect(find.text(NetworkException.defaultMessage), findsOneWidget);
      expect(_sentMessage, findsNothing);
      expect(textOf(tester, _emailField), _email);
    });

    testWidgets('deve mostrar o carregando durante o envio', (tester) async {
      final pending = fakes.auth.passwordResetPending = Completer<void>();
      await pumpView(tester);

      await send(tester);

      expect(find.bySemanticsLabel(RegExp('Carregando')), findsOneWidget);

      pending.complete();
      await tester.pump();
      await tester.pump(const Duration(minutes: 1));
    });

    testWidgets('deve voltar ao login com o e-mail pelo "Voltar ao login"', (tester) async {
      final results = <Object?>[];
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () async => results.add(await context.push<Object?>('/esqueci-senha')),
                child: const Text('Abrir'),
              ),
            ),
          ),
          GoRoute(
            path: '/esqueci-senha',
            builder: (_, _) => const ForgotPasswordView(initialEmail: _email),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpRouter(router, overrides: fakes.overrides);
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await send(tester);

      await tester.ensureVisible(find.text('Voltar ao login'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voltar ao login'));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordView), findsNothing);
      expect(results, [const LoginPrefill(email: _email)]);
    });

    testWidgets('deve anunciar a mensagem do envio ao leitor de tela', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpView(tester);

      await send(tester);

      expect(tester.getSemantics(_sentMessage), isSemantics(isLiveRegion: true));
      semantics.dispose();
      await tester.pump(const Duration(minutes: 1));
    });

    testWidgets('deve aguentar a fonte em 200%, com a mensagem do envio', (tester) async {
      tester.usePhoneScreen(textScale: 2);
      await pumpView(tester);

      await tester.ensureVisible(find.byType(FilledButton));
      await send(tester);

      expect(tester.takeException(), isNull);
      expect(_sentMessage, findsOneWidget);
      await tester.pump(const Duration(minutes: 1));
    });

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('deve passar nas verificações de acessibilidade (${themeMode.name})', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(800, 1600)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        await pumpView(tester, themeMode: themeMode);
        await send(tester);
        // O botão volta a ficar ativo no fim da espera, com a animação da cor.
        await tester.pump(const Duration(minutes: 1));
        await tester.pumpAndSettle();

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      });
    }
  });
}
