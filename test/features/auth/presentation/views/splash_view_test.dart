import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/views/splash_view.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_profile.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';
import '../../../../support/pump_app.dart';
import '../../../../support/sign_out.dart';

const _errorTitle = 'Não foi possível abrir a sua conta';

void main() {
  group('SplashView', () {
    late AuthFakes fakes;

    setUp(() => fakes = AuthFakes(signedIn: true));

    /// Abre a tela de abertura: o AuthController confere a sessão guardada.
    Future<void> pumpView(WidgetTester tester, {ThemeMode themeMode = ThemeMode.light}) async {
      await tester.pumpApp(const SplashView(), overrides: fakes.overrides, themeMode: themeMode);
      await tester.pump();
    }

    AuthState authState(WidgetTester tester) => tester.container().read(authControllerProvider);

    testWidgets('deve mostrar o carregando enquanto confere a sessão', (tester) async {
      final profile = fakes.profile.pending = Completer<UserProfile>();

      await pumpView(tester);

      expect(find.bySemanticsLabel('Carregando'), findsOneWidget);
      expect(find.text(_errorTitle), findsNothing);

      profile.complete(clientProfile);
      await tester.pump();
    });

    testWidgets('deve mostrar o erro, o "Tentar de novo" e o "Sair" sem rede (RM06)', (
      tester,
    ) async {
      fakes.profile.error = const NetworkException();

      await pumpView(tester);

      expect(find.text(_errorTitle), findsOneWidget);
      expect(find.text(NetworkException.defaultMessage), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
      expect(find.text('Sair'), findsOneWidget);
    });

    testWidgets('deve conferir de novo no "Tentar de novo", passando pelo carregando', (
      tester,
    ) async {
      fakes.profile.error = const NetworkException();
      await pumpView(tester);
      fakes.profile.error = null;
      final profile = fakes.profile.pending = Completer<UserProfile>();

      await tester.tap(find.text('Tentar de novo'));
      await tester.pump();

      expect(find.bySemanticsLabel('Carregando'), findsOneWidget);

      profile.complete(clientProfile);
      await tester.pump();

      expect(authState(tester), AuthAuthenticated(clientProfile));
      expect(fakes.profile.calls, 2);
    });

    testWidgets('deve encerrar a sessão no "Sair", depois da confirmação (RM10)', (tester) async {
      fakes.profile.error = const NetworkException();
      await pumpView(tester);

      await tester.signOutAndConfirm();

      expect(fakes.session.signOutCalls, 1);
      expect(authState(tester), const AuthUnauthenticated());
    });

    testWidgets('deve avisar e manter a sessão quando o "Sair" fica sem conexão (RM10)', (
      tester,
    ) async {
      fakes.profile.error = const NetworkException();
      fakes.session.signOutError = const NetworkException();
      await pumpView(tester);

      await tester.signOutAndConfirm();

      expect(find.widgetWithText(SnackBar, NetworkException.defaultMessage), findsOneWidget);
      expect(authState(tester), isA<AuthLoadFailed>());
      expect(fakes.session.hasStoredSession, isTrue);
    });

    for (final (state, setUpState) in [
      ('carregando', (AuthFakes f) => f.profile.pending = Completer<UserProfile>()),
      ('erro', (AuthFakes f) => f.profile.error = const NetworkException()),
    ]) {
      testWidgets('deve aguentar a fonte em 200% no estado de $state', (tester) async {
        tester.usePhoneScreen(textScale: 2);
        setUpState(fakes);

        await pumpView(tester);

        expect(tester.takeException(), isNull);
        fakes.profile.pending?.complete(clientProfile);
      });
    }

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('deve passar nas verificações de acessibilidade no erro (${themeMode.name})', (
        tester,
      ) async {
        fakes.profile.error = const NetworkException();
        final semantics = tester.ensureSemantics();
        await pumpView(tester, themeMode: themeMode);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      });
    }
  });
}
