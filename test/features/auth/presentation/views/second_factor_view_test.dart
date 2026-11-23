import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/view_models/second_factor_view_model.dart';
import 'package:reportaai_cm/features/auth/presentation/views/second_factor_view.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';
import '../../../../support/pump_app.dart';
import '../../../../support/sign_out.dart';

const _wrongCode = BusinessRuleException(message: 'Código inválido ou expirado.', field: 'code');

final Finder _codeField = find.widgetWithText(TextFormField, 'Código');
final Finder _confirm = find.widgetWithText(FilledButton, 'Confirmar');

void main() {
  group('SecondFactorView', () {
    late AuthFakes fakes;

    setUp(() {
      fakes = AuthFakes(signedIn: true);
      fakes.session.secondFactorPending = true;
    });

    /// Abre a tela com a sessão pendente. No app, o router cria o `AuthController`. Aqui, o
    /// teste o cria e espera a abertura chegar à sessão pendente.
    Future<void> pumpView(WidgetTester tester) async {
      await tester.pumpApp(const SecondFactorView(), overrides: fakes.overrides);
      tester.container().read(authControllerProvider);
      await tester.pump();
      expect(tester.container().read(authControllerProvider), const AuthSecondFactorPending());
    }

    /// Espera o fim da espera do "Enviar outro código", para o teste não terminar com o timer.
    Future<void> finishCountdown(WidgetTester tester) =>
        tester.pump(SecondFactorViewModel.resendInterval);

    Future<void> confirm(WidgetTester tester, String code) async {
      await tester.enterText(_codeField, code);
      // Com a fonte grande, o botão pode estar fora da tela.
      await tester.ensureVisible(_confirm);
      await tester.tap(_confirm);
      await tester.pump();
    }

    AuthState auth(WidgetTester tester) => tester.container().read(authControllerProvider);

    testWidgets('deve pedir o código, com o reenvio esperando 1 minuto (RM18)', (tester) async {
      await pumpView(tester);

      expect(find.text('Confira o seu e-mail'), findsOneWidget);
      expect(find.textContaining('código de 6 dígitos'), findsOneWidget);
      expect(_confirm, findsOneWidget);
      expect(find.text('Sair'), findsOneWidget);
      expect(find.text('Enviar outro código em 60 s'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Enviar outro código em 60 s'))
            .onPressed,
        isNull,
      );

      await tester.pump(const Duration(seconds: 60));

      expect(find.text('Enviar outro código'), findsOneWidget);
    });

    testWidgets('deve usar o teclado numérico, o preenchimento do código e 6 dígitos', (
      tester,
    ) async {
      await pumpView(tester);
      final field = tester.widget<EditableText>(
        find.descendant(of: _codeField, matching: find.byType(EditableText)),
      );

      expect(field.keyboardType, TextInputType.number);
      expect(field.autofillHints, [AutofillHints.oneTimeCode]);

      await tester.enterText(_codeField, '12a34567');
      expect(field.controller.text, '123456');
      await finishCountdown(tester);
    });

    testWidgets('deve entrar com o código certo', (tester) async {
      await pumpView(tester);

      await confirm(tester, '042137');

      expect(fakes.auth.verifyLoginCodeCalls, ['042137']);
      expect(auth(tester), AuthAuthenticated(clientProfile));
      await finishCountdown(tester);
    });

    testWidgets('deve confirmar pelo "concluir" do teclado', (tester) async {
      await pumpView(tester);

      await tester.enterText(_codeField, '042137');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(fakes.auth.verifyLoginCodeCalls, ['042137']);
      await finishCountdown(tester);
    });

    testWidgets('deve mostrar o carregando durante a conferência', (tester) async {
      await pumpView(tester);
      fakes.auth.verifyLoginCodePending = Completer<void>();

      await confirm(tester, '042137');

      expect(find.bySemanticsLabel(RegExp('Carregando')), findsOneWidget);
      fakes.auth.verifyLoginCodePending!.complete();
      await tester.pump();
      await finishCountdown(tester);
    });

    testWidgets('deve mostrar a mensagem da API embaixo do campo no código errado', (tester) async {
      await pumpView(tester);
      fakes.auth.verifyLoginCodeError = _wrongCode;

      await confirm(tester, '000000');

      expect(find.text('Código inválido ou expirado.'), findsOneWidget);
      expect(auth(tester), const AuthSecondFactorPending());
      expect(find.text(SecondFactorViewModel.invalidatedMessage), findsNothing);
      await finishCountdown(tester);
    });

    testWidgets('deve orientar a pedir outro código depois de 5 erros', (tester) async {
      await pumpView(tester);
      fakes.auth.verifyLoginCodeError = _wrongCode;

      for (var attempt = 0; attempt < 5; attempt++) {
        await confirm(tester, '000000');
      }

      expect(find.text(SecondFactorViewModel.invalidatedMessage), findsOneWidget);
      await finishCountdown(tester);
    });

    testWidgets('deve pedir o código com o campo vazio, sem chamar a API', (tester) async {
      await pumpView(tester);

      await tester.tap(_confirm);
      await tester.pump();

      expect(find.text(SecondFactorViewModel.codeMissingMessage), findsOneWidget);
      expect(fakes.auth.verifyLoginCodeCalls, isEmpty);
      await finishCountdown(tester);
    });

    testWidgets('deve mostrar o erro sem conexão', (tester) async {
      await pumpView(tester);
      fakes.auth.verifyLoginCodeError = const NetworkException();

      await confirm(tester, '042137');

      expect(find.text(NetworkException.defaultMessage), findsOneWidget);
      await finishCountdown(tester);
    });

    testWidgets('deve enviar outro código depois da espera e avisar o envio', (tester) async {
      await pumpView(tester);
      await finishCountdown(tester);

      await tester.tap(find.text('Enviar outro código'));
      await tester.pump();

      expect(fakes.auth.resendLoginCodeCalls, 1);
      expect(find.text(SecondFactorViewModel.sentMessage), findsOneWidget);
      expect(find.text('Enviar outro código em 60 s'), findsOneWidget);
      await finishCountdown(tester);
    });

    testWidgets('deve encerrar a sessão pendente pelo "Sair"', (tester) async {
      await pumpView(tester);

      await tester.signOutAndConfirm();
      await tester.pump();

      expect(fakes.session.signOutCalls, 1);
      expect(auth(tester), const AuthUnauthenticated());
    });

    testWidgets('deve aguentar a fonte em 200%, com o erro do código', (tester) async {
      tester.usePhoneScreen(textScale: 2);
      await pumpView(tester);
      fakes.auth.verifyLoginCodeError = _wrongCode;
      for (var attempt = 0; attempt < 5; attempt++) {
        await confirm(tester, '000000');
      }

      expect(tester.takeException(), isNull);
      expect(find.text(SecondFactorViewModel.invalidatedMessage), findsOneWidget);
      await finishCountdown(tester);
    });

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('deve passar nas verificações de acessibilidade (${themeMode.name})', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(800, 2400)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        await tester.pumpApp(
          const SecondFactorView(),
          overrides: fakes.overrides,
          themeMode: themeMode,
        );
        tester.container().read(authControllerProvider);
        await tester.pump();
        fakes.auth.verifyLoginCodeError = _wrongCode;
        await confirm(tester, '000000');

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
        await finishCountdown(tester);
      });
    }
  });
}
