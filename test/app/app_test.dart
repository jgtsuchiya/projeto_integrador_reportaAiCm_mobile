import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/features/auth/presentation/views/login_view.dart';

import '../support/auth_fakes.dart';
import '../support/pump_app.dart';

void main() {
  group('App', () {
    /// Abre o app sem sessão: ele para no login.
    Future<BuildContext> pumpWholeApp(WidgetTester tester) async {
      await tester.pumpWholeApp(overrides: AuthFakes().overrides);
      await tester.pumpAndSettle();
      return tester.element(find.byType(LoginView));
    }

    testWidgets('deve abrir em pt-BR', (tester) async {
      final context = await pumpWholeApp(tester);

      expect(Localizations.localeOf(context), const Locale('pt', 'BR'));
      expect(MaterialLocalizations.of(context).cancelButtonLabel, 'Cancelar');
    });

    testWidgets('deve usar o tema claro com o sistema no modo claro', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final context = await pumpWholeApp(tester);

      expect(Theme.of(context).brightness, Brightness.light);
      expect(Theme.of(context).useMaterial3, isTrue);
    });

    testWidgets('deve trocar para o tema escuro junto com o sistema', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpWholeApp(tester);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();

      expect(Theme.of(tester.element(find.byType(LoginView))).brightness, Brightness.dark);
    });
  });

  test('o app não deve repetir sozinho um provider que falhou', () {
    expect(noAutomaticRetry(0, Exception('falha')), isNull);
  });
}
