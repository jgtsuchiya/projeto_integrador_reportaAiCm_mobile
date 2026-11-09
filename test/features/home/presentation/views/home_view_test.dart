import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/home/presentation/views/home_view.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';
import '../../../../support/pump_app.dart';

void main() {
  group('HomeView', () {
    late AuthFakes fakes;

    setUp(() => fakes = AuthFakes(signedIn: true));

    /// Abre a tela inicial com o Client já dentro.
    Future<void> pumpView(WidgetTester tester, {ThemeMode themeMode = ThemeMode.light}) async {
      await tester.pumpApp(const HomeView(), overrides: fakes.overrides, themeMode: themeMode);
      await tester.pump();
    }

    testWidgets('deve mostrar o nome do app e quem entrou', (tester) async {
      await pumpView(tester);

      expect(find.text('ReportaAi Cm'), findsOneWidget);
      expect(find.text(clientProfile.name), findsOneWidget);
      expect(find.text(clientProfile.email), findsOneWidget);
    });

    testWidgets('não deve mostrar o CPF (RM09)', (tester) async {
      await pumpView(tester);

      expect(find.textContaining(clientProfile.cpf!), findsNothing);
    });

    testWidgets('deve sair pelo "Sair" da barra superior', (tester) async {
      await pumpView(tester);

      await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.text('Sair')));
      await tester.pump();

      expect(fakes.session.signOutCalls, 1);
      expect(tester.container().read(authControllerProvider), const AuthUnauthenticated());
      expect(find.text(clientProfile.name), findsNothing);
    });

    testWidgets('deve aguentar a fonte em 200%', (tester) async {
      tester.usePhoneScreen(textScale: 2);

      await pumpView(tester);

      expect(tester.takeException(), isNull);
    });

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('deve passar nas verificações de acessibilidade (${themeMode.name})', (
        tester,
      ) async {
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
