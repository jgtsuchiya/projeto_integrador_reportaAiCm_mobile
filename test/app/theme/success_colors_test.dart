import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/theme/app_theme.dart';
import 'package:reportaai_cm/app/theme/success_colors.dart';

import '../../support/pump_app.dart';

void main() {
  group('SuccessColors', () {
    const colors = AppTheme.successColors;
    const black = Color(0xFF000000);
    const white = Color(0xFFFFFFFF);

    testWidgets('deve vir do tema do app pelo SuccessColors.of', (tester) async {
      await tester.pumpApp(const Scaffold(body: Text('Tela')));

      expect(SuccessColors.of(tester.element(find.text('Tela'))), colors);
    });

    test('deve trocar só as cores passadas no copyWith', () {
      final copy = colors.copyWith(success: black);

      expect(copy.success, black);
      expect(copy.onSuccess, colors.onSuccess);
      expect(copy.successContainer, colors.successContainer);
      expect(copy.onSuccessContainer, colors.onSuccessContainer);
    });

    test('deve misturar as cores no lerp', () {
      const from = SuccessColors(
        success: black,
        onSuccess: black,
        successContainer: black,
        onSuccessContainer: black,
      );
      const to = SuccessColors(
        success: white,
        onSuccess: white,
        successContainer: white,
        onSuccessContainer: white,
      );

      expect(from.lerp(to, 0).success, black);
      expect(from.lerp(to, 1).onSuccessContainer, white);
      expect(from.lerp(to, 0.5).successContainer, Color.lerp(black, white, 0.5));
      expect(from.lerp(null, 0.5), from);
    });
  });
}
