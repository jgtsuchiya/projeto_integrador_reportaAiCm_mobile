import 'dart:async';

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

    Future<void> fillIn(WidgetTester tester) async {
      await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), _email);
      await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), _password);
    }

    testWidgets('deve mostrar o e-mail, a senha e o "Entrar", sem aviso', (tester) async {
      await pumpView(tester);

      expect(find.widgetWithText(TextFormField, 'E-mail'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Senha'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
      expect(find.text(UnauthenticatedReason.sessionExpired.message), findsNothing);
    });

    testWidgets('deve mostrar o motivo de ter voltado ao login (RM01)', (tester) async {
      fakes.session.hasStoredSession = true;
      fakes.profile.result = adminProfile;

      await pumpView(tester);

      expect(find.text(UnauthenticatedReason.roleNotAllowed.message), findsOneWidget);
    });

    testWidgets('deve entrar com o e-mail e a senha digitados', (tester) async {
      await pumpView(tester);
      await fillIn(tester);

      await tester.tap(find.text('Entrar'));
      await tester.pump();

      expect(fakes.auth.signInCalls.single, (email: _email, password: _password));
      expect(tester.container().read(authControllerProvider), AuthAuthenticated(clientProfile));
    });

    testWidgets('deve enviar pelo "concluir" do teclado no campo de senha', (tester) async {
      await pumpView(tester);
      await fillIn(tester);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(fakes.auth.signInCalls, hasLength(1));
    });

    testWidgets('deve mostrar o aviso do login que não entrou (RM02)', (tester) async {
      fakes.auth.signInResult = const SignInWrongCredentials();
      await pumpView(tester);
      await fillIn(tester);

      await tester.tap(find.text('Entrar'));
      await tester.pump();

      expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    });

    testWidgets('deve mostrar a mensagem sem conexão', (tester) async {
      fakes.auth.signInError = const NetworkException();
      await pumpView(tester);
      await fillIn(tester);

      await tester.tap(find.text('Entrar'));
      await tester.pump();

      expect(find.text(NetworkException.defaultMessage), findsOneWidget);
    });

    testWidgets('deve trocar o motivo pelo aviso do novo login', (tester) async {
      fakes.session.hasStoredSession = true;
      fakes.profile.error = const UnauthorizedException();
      fakes.auth.signInResult = const SignInWrongCredentials();
      await pumpView(tester);
      expect(find.text(UnauthenticatedReason.sessionExpired.message), findsOneWidget);
      await fillIn(tester);

      await tester.tap(find.text('Entrar'));
      await tester.pump();

      expect(find.text(UnauthenticatedReason.sessionExpired.message), findsNothing);
      expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    });

    testWidgets('deve mostrar o carregando e não enviar duas vezes', (tester) async {
      final pending = fakes.auth.signInPending = Completer<SignInResult>();
      await pumpView(tester);
      await fillIn(tester);

      await tester.tap(find.text('Entrar'));
      await tester.pump();
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

    testWidgets('deve aguentar a fonte em 200%, com o aviso', (tester) async {
      tester.usePhoneScreen(textScale: 2);
      fakes.session.hasStoredSession = true;
      fakes.profile.result = adminProfile;

      await pumpView(tester, showDiagnostics: true);

      expect(tester.takeException(), isNull);
      expect(find.text(UnauthenticatedReason.roleNotAllowed.message), findsOneWidget);
    });

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('deve passar nas verificações de acessibilidade (${themeMode.name})', (
        tester,
      ) async {
        fakes.session.hasStoredSession = true;
        fakes.profile.error = const UnauthorizedException();
        final semantics = tester.ensureSemantics();
        await pumpView(tester, themeMode: themeMode, showDiagnostics: true);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      });
    }
  });
}
