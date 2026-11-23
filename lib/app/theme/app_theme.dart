import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/theme/app_colors.dart';
import 'package:reportaai_cm/app/theme/success_colors.dart';

/// Tema Material 3 com as cores da UTFPR ([AppColors]), só claro: o app fica claro mesmo com o
/// modo escuro ligado no aparelho. A tipografia é a padrão do Material 3 (Roboto no Android e a
/// fonte do sistema no iOS), que acompanha o tamanho de fonte do sistema.
abstract final class AppTheme {
  /// O [ColorScheme] parte do amarelo com a variante `monochrome`, que gera as superfícies e os
  /// contornos em cinza neutro, como os do portal, e o vermelho padrão do Material 3 nos erros. A
  /// variante padrão (`tonalSpot`) daria um `primary` mostarda-escuro e superfícies amareladas.
  ///
  /// Os papéis da marca vêm das cores do portal. O `primary` é a tinta (os ícones grandes, os
  /// `TextButton`, o foco dos campos e os indicadores de carregamento), e o amarelo é o
  /// `primaryContainer`: um fundo, com a tinta por cima. O `inversePrimary` amarelo é a ação do
  /// `SnackBar`, sobre o fundo escuro do aviso.
  static final ColorScheme colorScheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.yellow,
        dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
      ).copyWith(
        primary: AppColors.ink,
        onPrimary: Colors.white,
        primaryContainer: AppColors.yellow,
        onPrimaryContainer: AppColors.ink,
        inversePrimary: AppColors.yellow,
        secondary: AppColors.gray800,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.gray300,
        onSecondaryContainer: AppColors.ink,
        tertiary: AppColors.blue,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.blueLight,
        onTertiaryContainer: AppColors.navy,
      );

  /// O verde de sucesso do portal.
  static const successColors = SuccessColors(
    success: AppColors.green900,
    onSuccess: Colors.white,
    successContainer: AppColors.green50,
    onSuccessContainer: AppColors.green900,
  );

  /// O estilo do `FilledButton.tonal`: o cinza do `secondaryContainer`, com a tinta por cima. O
  /// `filledButtonTheme` vale também para o tonal, que, sem este estilo, ficaria amarelo como o
  /// botão principal.
  static final ButtonStyle tonalButtonStyle = FilledButton.styleFrom(
    backgroundColor: colorScheme.secondaryContainer,
    foregroundColor: colorScheme.onSecondaryContainer,
  );

  static final ThemeData light = _build();

  /// A área de toque mínima recomendada para Android e iOS.
  static const minTapTarget = 48.0;

  static ThemeData _build() {
    const buttonSize = Size(64, minTapTarget);

    return ThemeData(
      colorScheme: colorScheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      // O botão principal é amarelo, com o texto em tinta, como a faixa do portal.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: buttonSize),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(minimumSize: buttonSize)),
      inputDecorationTheme: const InputDecorationThemeData(border: OutlineInputBorder()),
      extensions: const [successColors],
    );
  }
}
