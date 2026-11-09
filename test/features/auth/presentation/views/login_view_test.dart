import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/domain/models/sign_in_result.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/views/login_view.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';
import '../../../../support/pump_app.dart';

const _email = 'maria.silva@exemplo.com';
const _password = 'SenhaSecreta123';

final Finder _emailField = find.widgetWithText(TextFormField, 'E-mail');
final Finder _passwordField = find.widgetWithText(TextFormField, 'Senha');

void main() {
  group('LoginView', () {
    late AuthFakes fakes;

    setUp(() => fakes = AuthFakes());

    /// Abre o login, depois da abertura: sem a sessão guardada, ou com o motivo de ter voltado.
    Future<void> pumpView(
      WidgetTester tester, {
      bool showDiagnostics = false,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      await tester.pumpApp(
        LoginView(showDiagnostics: showDiagnostics),
        overrides: fakes.overrides,
        themeMode: themeMode,
      );
      await tester.pump();
    }

    Future<void> fillIn(WidgetTester tester, {String email = _email}) async {
      await tester.enterText(_emailField, email);
      await tester.enterText(_passwordField, _password);
    }

    Future<void> signIn(WidgetTester tester) async {
      await tester.tap(find.text('Entrar'));
      await tester.pump();
    }

    String textOf(WidgetTester tester, Finder field) => tester
        .widget<EditableText>(find.descendant(of: field, matching: find.byType(EditableText)))
        .controller
        .text;

    TextField textFieldOf(WidgetTester tester, Finder field) =>
        tester.widget<TextField>(find.descendant(of: field, matching: find.byType(TextField)));

    Finder errorBelow(Finder field, String message) =>
        find.descendant(of: field, matching: find.text(message));

    VoidCallback? onSignIn(WidgetTester tester) =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Entrar')).onPressed;

    Iterable<MethodCall> finishAutofillCalls(WidgetTester tester) =>
        tester.testTextInput.log.where((call) => call.method == 'TextInput.finishAutofillContext');

    testWidgets('deve mostrar o e-mail, a senha e o "Entrar", sem aviso', (tester) async {
      await pumpView(tester);

      expect(_emailField, findsOneWidget);
      expect(_passwordField, findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
      expect(find.text(UnauthenticatedReason.sessionExpired.message), findsNothing);
    });

    testWidgets('deve mostrar o motivo de ter voltado ao login (RM01)', (tester) async {
      fakes.session.hasStoredSession = true;
      fakes.profile.result = adminProfile;

      await pumpView(tester);

      expect(find.text(UnauthenticatedReason.roleNotAllowed.message), findsOneWidget);
    });

    group('campos', () {
      testWidgets('deve usar o teclado de e-mail, sem correção automática', (tester) async {
        await pumpView(tester);

        final email = textFieldOf(tester, _emailField);

        expect(email.keyboardType, TextInputType.emailAddress);
        expect(email.autocorrect, isFalse);
        expect(email.textInputAction, TextInputAction.next);
      });

      testWidgets('deve ocultar a senha e mostrar pelo botão, sem sugestão do teclado', (
        tester,
      ) async {
        await pumpView(tester);
        await tester.enterText(_passwordField, _password);

        expect(textFieldOf(tester, _passwordField).obscureText, isTrue);

        await tester.tap(find.byTooltip('Mostrar senha'));
        await tester.pump();

        final password = textFieldOf(tester, _passwordField);
        expect(password.obscureText, isFalse);
        expect(password.autocorrect, isFalse);
        expect(password.enableSuggestions, isFalse);
        expect(password.enableIMEPersonalizedLearning, isFalse);
        expect(textOf(tester, _passwordField), _password);

        await tester.tap(find.byTooltip('Ocultar senha'));
        await tester.pump();

        expect(textFieldOf(tester, _passwordField).obscureText, isTrue);
      });

      testWidgets('deve deixar o gerenciador de senhas preencher o e-mail e a senha', (
        tester,
      ) async {
        await pumpView(tester);

        expect(textFieldOf(tester, _emailField).autofillHints, [AutofillHints.email]);
        expect(textFieldOf(tester, _passwordField).autofillHints, [AutofillHints.password]);
        expect(
          find.ancestor(of: _passwordField, matching: find.byType(AutofillGroup)),
          findsOneWidget,
        );
        expect(
          find.ancestor(of: _emailField, matching: find.byType(AutofillGroup)),
          findsOneWidget,
        );
        // Sair da tela sem entrar não oferece salvar a senha.
        expect(
          tester.widget<AutofillGroup>(find.byType(AutofillGroup)).onDisposeAction,
          AutofillContextAction.cancel,
        );
      });
    });

    group('conferência antes de enviar (RM05)', () {
      testWidgets('deve pedir o e-mail e a senha embaixo de cada campo, sem chamar a API', (
        tester,
      ) async {
        await pumpView(tester);

        await signIn(tester);

        expect(errorBelow(_emailField, SignInFieldError.emailRequiredMessage), findsOneWidget);
        expect(
          errorBelow(_passwordField, SignInFieldError.passwordRequiredMessage),
          findsOneWidget,
        );
        expect(fakes.auth.signInCalls, isEmpty);
      });

      testWidgets('deve recusar o e-mail fora do formato', (tester) async {
        await pumpView(tester);
        await fillIn(tester, email: 'maria@exemplo');

        await signIn(tester);

        expect(errorBelow(_emailField, SignInFieldError.emailInvalidMessage), findsOneWidget);
        expect(fakes.auth.signInCalls, isEmpty);
      });

      testWidgets('deve tirar o erro do campo quando o usuário o edita', (tester) async {
        await pumpView(tester);
        await signIn(tester);

        await tester.enterText(_emailField, 'm');
        await tester.pump();

        expect(find.text(SignInFieldError.emailRequiredMessage), findsNothing);
        expect(find.text(SignInFieldError.passwordRequiredMessage), findsOneWidget);
      });
    });

    group('respostas do login', () {
      testWidgets('deve entrar com o e-mail e a senha digitados e oferecer salvar a senha', (
        tester,
      ) async {
        await pumpView(tester);
        await fillIn(tester);

        await signIn(tester);

        expect(fakes.auth.signInCalls.single, (email: _email, password: _password));
        expect(tester.container().read(authControllerProvider), AuthAuthenticated(clientProfile));
        expect(finishAutofillCalls(tester).single.arguments, isTrue);
      });

      testWidgets('deve enviar pelo "concluir" do teclado no campo de senha', (tester) async {
        await pumpView(tester);
        await fillIn(tester);

        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        expect(fakes.auth.signInCalls, hasLength(1));
      });

      testWidgets('deve apagar a senha e manter o e-mail na senha errada (RM02)', (tester) async {
        fakes.auth.signInResult = const SignInWrongCredentials();
        await pumpView(tester);
        await fillIn(tester);

        await signIn(tester);

        expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
        expect(textOf(tester, _emailField), _email);
        expect(textOf(tester, _passwordField), isEmpty);
        // A senha errada não é oferecida ao gerenciador de senhas.
        expect(finishAutofillCalls(tester), isEmpty);
      });

      testWidgets('deve mostrar o erro do FIELD_ERROR embaixo de cada campo', (tester) async {
        fakes.auth.signInResult = const SignInFieldError({
          SignInField.email: SignInFieldError.emailInvalidMessage,
          SignInField.password: SignInFieldError.passwordRequiredMessage,
        });
        await pumpView(tester);
        await fillIn(tester);

        await signIn(tester);

        expect(errorBelow(_emailField, SignInFieldError.emailInvalidMessage), findsOneWidget);
        expect(
          errorBelow(_passwordField, SignInFieldError.passwordRequiredMessage),
          findsOneWidget,
        );
      });

      testWidgets('deve mostrar a mensagem da API no bloqueio por tentativas (RM03)', (
        tester,
      ) async {
        const message = 'Muitas tentativas de login. Tente de novo em alguns minutos.';
        fakes.auth.signInResult = const SignInLocked(message);
        await pumpView(tester);
        await fillIn(tester);

        await signIn(tester);

        expect(find.text(message), findsOneWidget);
        expect(onSignIn(tester), isNotNull);
      });

      testWidgets(
        'deve desativar o "Entrar" com a contagem do limite por IP e voltar sozinho (RM04)',
        (tester) async {
          fakes.auth.signInResult = const SignInRateLimited(retryAfter: Duration(seconds: 3));
          await pumpView(tester);
          await fillIn(tester);

          await signIn(tester);

          expect(find.text('Muitas tentativas. Tente de novo em 3 s.'), findsOneWidget);
          expect(onSignIn(tester), isNull);

          await tester.pump(const Duration(seconds: 1));

          expect(find.text('Muitas tentativas. Tente de novo em 2 s.'), findsOneWidget);
          expect(onSignIn(tester), isNull);

          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pump(const Duration(seconds: 2));

          expect(find.textContaining('Muitas tentativas'), findsNothing);
          expect(onSignIn(tester), isNotNull);
          expect(fakes.auth.signInCalls, hasLength(1));
        },
      );

      for (final (description, error) in [
        ('sem conexão', const NetworkException()),
        ('no 5xx ou na resposta inesperada', const ServerException(statusCode: 500)),
      ]) {
        testWidgets('deve mostrar a mensagem $description', (tester) async {
          fakes.auth.signInError = error;
          await pumpView(tester);
          await fillIn(tester);

          await signIn(tester);

          expect(find.text(error.message), findsOneWidget);
          expect(textOf(tester, _passwordField), _password);
        });
      }
    });

    testWidgets('deve trocar o motivo pelo aviso do novo login', (tester) async {
      fakes.session.hasStoredSession = true;
      fakes.profile.error = const UnauthorizedException();
      fakes.auth.signInResult = const SignInWrongCredentials();
      await pumpView(tester);
      expect(find.text(UnauthenticatedReason.sessionExpired.message), findsOneWidget);
      await fillIn(tester);

      await signIn(tester);

      expect(find.text(UnauthenticatedReason.sessionExpired.message), findsNothing);
      expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    });

    testWidgets('deve mostrar o carregando e não enviar duas vezes', (tester) async {
      final pending = fakes.auth.signInPending = Completer<SignInResult>();
      await pumpView(tester);
      await fillIn(tester);

      await signIn(tester);
      await tester.tap(find.text('Entrar'), warnIfMissed: false);
      await tester.pump();

      expect(find.bySemanticsLabel(RegExp('Carregando')), findsOneWidget);
      expect(fakes.auth.signInCalls, hasLength(1));

      pending.complete(const SignInWrongCredentials());
      await tester.pump();
    });

    testWidgets('deve mostrar o atalho do diagnóstico só quando ele existe', (tester) async {
      await pumpView(tester, showDiagnostics: true);

      expect(find.text('Diagnóstico da API'), findsOneWidget);

      await pumpView(tester);

      expect(find.text('Diagnóstico da API'), findsNothing);
    });

    group('leitor de tela', () {
      testWidgets('deve ler o rótulo dos campos e do botão da senha', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpView(tester);

        expect(
          tester.getSemantics(find.descendant(of: _emailField, matching: find.byType(TextField))),
          isSemantics(label: 'E-mail', isTextField: true),
        );
        expect(
          tester.getSemantics(
            find.descendant(of: _passwordField, matching: find.byType(TextField)),
          ),
          isSemantics(label: 'Senha', isTextField: true, isObscured: true),
        );
        // O leitor de tela lê o tooltip do botão, que não tem outro rótulo.
        expect(
          tester.getSemantics(find.byTooltip('Mostrar senha')),
          isSemantics(tooltip: 'Mostrar senha', isButton: true),
        );
        semantics.dispose();
      });

      testWidgets('deve anunciar o aviso do login que não entrou', (tester) async {
        fakes.auth.signInResult = const SignInWrongCredentials();
        final semantics = tester.ensureSemantics();
        await pumpView(tester);
        await fillIn(tester);

        await signIn(tester);

        expect(
          tester.getSemantics(find.text('E-mail ou senha incorretos.')),
          isSemantics(label: 'E-mail ou senha incorretos.', isLiveRegion: true),
        );
        semantics.dispose();
      });

      testWidgets('deve anunciar a contagem do 429 só quando ela começa', (tester) async {
        fakes.auth.signInResult = const SignInRateLimited(retryAfter: Duration(seconds: 3));
        final semantics = tester.ensureSemantics();
        await pumpView(tester);
        await fillIn(tester);

        await signIn(tester);

        expect(
          tester.getSemantics(find.text('Muitas tentativas. Tente de novo em 3 s.')),
          isSemantics(isLiveRegion: true),
        );

        await tester.pump(const Duration(seconds: 1));

        expect(
          tester.getSemantics(find.text('Muitas tentativas. Tente de novo em 2 s.')),
          isSemantics(label: 'Muitas tentativas. Tente de novo em 2 s.', isLiveRegion: false),
        );

        await tester.pump(const Duration(seconds: 2));
        semantics.dispose();
      });
    });

    testWidgets('deve aguentar a fonte em 200%, com o aviso e os erros dos campos', (tester) async {
      tester.usePhoneScreen(textScale: 2);
      fakes.session.hasStoredSession = true;
      fakes.profile.result = adminProfile;
      await pumpView(tester, showDiagnostics: true);

      await tester.ensureVisible(find.text('Entrar'));
      await signIn(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(UnauthenticatedReason.roleNotAllowed.message), findsOneWidget);
      expect(find.text(SignInFieldError.emailRequiredMessage), findsOneWidget);
    });

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('deve passar nas verificações de acessibilidade (${themeMode.name})', (
        tester,
      ) async {
        fakes.session.hasStoredSession = true;
        fakes.profile.error = const UnauthorizedException();
        final semantics = tester.ensureSemantics();
        await pumpView(tester, themeMode: themeMode, showDiagnostics: true);
        await signIn(tester);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      });
    }
  });
}
