import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/theme/app_colors.dart';

/// Tema Material 3, claro e escuro, a partir da cor-base. A tipografia é a padrão do Material 3
/// (Roboto no Android e a fonte do sistema no iOS), que acompanha o tamanho de fonte do sistema.
abstract final class AppTheme {
  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  /// A área de toque mínima recomendada para Android e iOS.
  static const minTapTarget = 48.0;

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(seedColor: AppColors.seed, brightness: brightness);
    const buttonSize = Size(64, minTapTarget);

    return ThemeData(
      colorScheme: colorScheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: buttonSize),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: buttonSize),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(minimumSize: buttonSize)),
      inputDecorationTheme: const InputDecorationThemeData(border: OutlineInputBorder()),
    );
  }
}
