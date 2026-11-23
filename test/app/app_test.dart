import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/app/theme/app_theme.dart';
import 'package:reportaai_cm/app/theme/success_colors.dart';
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

    testWidgets('deve usar o tema do app, com as cores da UTFPR', (tester) async {
      final context = await pumpWholeApp(tester);
      final theme = Theme.of(context);

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme, AppTheme.colorScheme);
      expect(theme.extension<SuccessColors>(), AppTheme.successColors);
    });

    for (final brightness in Brightness.values) {
      testWidgets('deve ficar no tema claro com o sistema no modo ${brightness.name}', (
        tester,
      ) async {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

        final context = await pumpWholeApp(tester);

        expect(Theme.of(context).brightness, Brightness.light);
      });
    }

    testWidgets('deve continuar no tema claro quando o sistema troca para o modo escuro', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpWholeApp(tester);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();

      expect(Theme.of(tester.element(find.byType(LoginView))).brightness, Brightness.light);
    });
  });

  test('o app não deve repetir sozinho um provider que falhou', () {
    expect(noAutomaticRetry(0, Exception('falha')), isNull);
  });
}
