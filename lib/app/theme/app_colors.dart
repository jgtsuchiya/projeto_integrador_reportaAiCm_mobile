import 'package:material_ui/material_ui.dart';

/// As cores do app, tiradas do portal da UTFPR (https://www.utfpr.edu.br/): as variáveis `--ds-*`
/// do design system do site e as classes do HTML, consultadas em 23/11/2026. O portal não publica
/// um manual de marca: com os valores oficiais, a troca fica só aqui, e o teste de contraste do
/// tema avisa se algum par deixar de passar.
///
/// As telas usam o `colorScheme` e a `SuccessColors` do `AppTheme`, e não estas cores. A exceção é
/// o [photoBackdrop], que não é um papel do tema.
abstract final class AppColors {
  /// O amarelo da faixa do topo do portal (`--ds-yellow-500`). O portal usa também o `#FCBC00` nos
  /// destaques: a diferença não aparece, e o app usa um só.
  ///
  /// Nunca é cor de texto nem de ícone (1,58:1 sobre a superfície do tema): é sempre um fundo,
  /// com a [ink] por cima (10,65:1), como na faixa do portal.
  static const yellow = Color(0xFFFFBE00);

  /// A tinta do texto das páginas do portal (`--ds-gray-900`).
  static const ink = Color(0xFF18181A);

  /// O cinza-escuro do portal (`--ds-gray-800`).
  static const gray800 = Color(0xFF464646);

  /// O cinza-claro do portal (`--ds-gray-300`).
  static const gray300 = Color(0xFFE4E4E4);

  /// O azul dos links e do realce do menu do portal.
  static const blue = Color(0xFF005DB7);

  /// O azul-claro do fundo do item do menu em realce, no portal.
  static const blueLight = Color(0xFFA9C7FF);

  /// O azul-marinho do fundo da barra inferior do portal, no modo escuro.
  static const navy = Color(0xFF001C3A);

  /// O verde do portal (`--ds-green-900`).
  static const green900 = Color(0xFF006A00);

  /// O verde-claro do portal (`--ds-green-50`).
  static const green50 = Color(0xFFE7F7E5);

  /// O fundo da foto ampliada. Não é do portal: o preto deixa a foto em destaque.
  static const photoBackdrop = Color(0xFF000000);
}
