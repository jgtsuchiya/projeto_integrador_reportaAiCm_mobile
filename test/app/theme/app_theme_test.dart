import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/theme/app_colors.dart';
import 'package:reportaai_cm/app/theme/app_theme.dart';
import 'package:reportaai_cm/app/theme/success_colors.dart';

import '../../support/pump_app.dart';

/// O contraste mínimo do WCAG (AA) para texto. Os ícones pedem 3:1, e o teste cobra o 4,5:1 de
/// todos os pares.
const minimumContrast = 4.5;

void main() {
  const success = AppTheme.successColors;
  final colors = AppTheme.colorScheme;

  group('AppTheme', () {
    test('deve ser só o tema claro do Material 3, com a SuccessColors', () {
      final theme = AppTheme.light;

      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme, colors);
      expect(theme.extension<SuccessColors>(), success);
    });

    test('deve usar as cores da UTFPR nos papéis da marca', () {
      expect(colors.primary, AppColors.ink);
      expect(colors.primaryContainer, AppColors.yellow);
      expect(colors.onPrimaryContainer, AppColors.ink);
      expect(colors.inversePrimary, AppColors.yellow);
      expect(colors.secondary, AppColors.gray800);
      expect(colors.secondaryContainer, AppColors.gray300);
      expect(colors.tertiary, AppColors.blue);
      expect(colors.tertiaryContainer, AppColors.blueLight);
      expect(colors.onTertiaryContainer, AppColors.navy);
      expect(success.success, AppColors.green900);
      expect(success.successContainer, AppColors.green50);
    });

    test('deve gerar as superfícies e os contornos em cinza neutro, como os do portal', () {
      for (final (name, color) in [
        ('surface', colors.surface),
        ('surfaceContainerHighest', colors.surfaceContainerHighest),
        ('onSurface', colors.onSurface),
        ('onSurfaceVariant', colors.onSurfaceVariant),
        ('outline', colors.outline),
        ('outlineVariant', colors.outlineVariant),
      ]) {
        expect(color.r, color.g, reason: name);
        expect(color.g, color.b, reason: name);
      }
    });

    test('deve ter o contraste mínimo em cada par do tema (fundo e conteúdo)', () {
      final failures = contrastFailures(themePairs(colors, success));

      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    testWidgets('deve deixar o FilledButton amarelo com o texto em tinta, e o tonal no cinza', (
      tester,
    ) async {
      await tester.pumpApp(
        Scaffold(
          body: Column(
            children: [
              FilledButton(onPressed: () {}, child: const Text('Principal')),
              FilledButton.tonal(
                onPressed: () {},
                style: AppTheme.tonalButtonStyle,
                child: const Text('Tonal'),
              ),
            ],
          ),
        ),
      );

      Material buttonOf(String label) => tester.widget<Material>(
        find.ancestor(of: find.text(label), matching: find.byType(Material)).first,
      );

      expect(buttonOf('Principal').color, colors.primaryContainer);
      expect(buttonOf('Principal').textStyle?.color, colors.onPrimaryContainer);
      expect(buttonOf('Tonal').color, colors.secondaryContainer);
      expect(buttonOf('Tonal').textStyle?.color, colors.onSecondaryContainer);
    });
  });

  group('Verificação do contraste', () {
    test('deve dar 21:1 no preto sobre o branco e 1:1 na mesma cor', () {
      expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
      expect(contrastRatio(AppColors.yellow, AppColors.yellow), 1);
    });

    test('deve acusar o amarelo como texto sobre a superfície', () {
      final failures = contrastFailures([
        (name: 'amarelo na surface', content: AppColors.yellow, background: colors.surface),
        (name: 'tinta no amarelo', content: AppColors.ink, background: AppColors.yellow),
      ]);

      expect(failures, hasLength(1));
      expect(failures.single, startsWith('amarelo na surface: 1.58:1'));
    });
  });
}

/// Um par do tema: o `content` (texto ou ícone) sobre o `background`.
typedef ContrastPair = ({String name, Color content, Color background});

/// Os pares do tema, como as telas usam: as cores de texto e de ícone (`primary`, `secondary`,
/// `tertiary`, `error` e o `success`) sobre a superfície, e cada `on*` sobre o fundo dele. Uma
/// troca de cor no `AppColors` que quebre a leitura de algum par faz o teste falhar.
List<ContrastPair> themePairs(ColorScheme colors, SuccessColors success) => [
  (name: 'primary na surface', content: colors.primary, background: colors.surface),
  (name: 'onPrimary no primary', content: colors.onPrimary, background: colors.primary),
  (
    name: 'onPrimaryContainer no primaryContainer',
    content: colors.onPrimaryContainer,
    background: colors.primaryContainer,
  ),
  (
    name: 'inversePrimary no inverseSurface',
    content: colors.inversePrimary,
    background: colors.inverseSurface,
  ),
  (name: 'secondary na surface', content: colors.secondary, background: colors.surface),
  (name: 'onSecondary no secondary', content: colors.onSecondary, background: colors.secondary),
  (
    name: 'onSecondaryContainer no secondaryContainer',
    content: colors.onSecondaryContainer,
    background: colors.secondaryContainer,
  ),
  (name: 'tertiary na surface', content: colors.tertiary, background: colors.surface),
  (name: 'onTertiary no tertiary', content: colors.onTertiary, background: colors.tertiary),
  (
    name: 'onTertiaryContainer no tertiaryContainer',
    content: colors.onTertiaryContainer,
    background: colors.tertiaryContainer,
  ),
  (name: 'success na surface', content: success.success, background: colors.surface),
  (name: 'onSuccess no success', content: success.onSuccess, background: success.success),
  (
    name: 'onSuccessContainer no successContainer',
    content: success.onSuccessContainer,
    background: success.successContainer,
  ),
  (name: 'error na surface', content: colors.error, background: colors.surface),
  (name: 'onError no error', content: colors.onError, background: colors.error),
  (
    name: 'onErrorContainer no errorContainer',
    content: colors.onErrorContainer,
    background: colors.errorContainer,
  ),
  (name: 'onSurface na surface', content: colors.onSurface, background: colors.surface),
  (
    name: 'onSurfaceVariant na surface',
    content: colors.onSurfaceVariant,
    background: colors.surface,
  ),
  (
    name: 'onSurface no surfaceContainerHighest',
    content: colors.onSurface,
    background: colors.surfaceContainerHighest,
  ),
  (
    name: 'onSurfaceVariant no surfaceContainerHighest',
    content: colors.onSurfaceVariant,
    background: colors.surfaceContainerHighest,
  ),
  (
    name: 'onInverseSurface no inverseSurface',
    content: colors.onInverseSurface,
    background: colors.inverseSurface,
  ),
];

/// Os pares abaixo do [minimumContrast], como "nome: contraste".
List<String> contrastFailures(List<ContrastPair> pairs) => [
  for (final (:name, :content, :background) in pairs)
    if (contrastRatio(content, background) case final ratio when ratio < minimumContrast)
      '$name: ${ratio.toStringAsFixed(2)}:1 (mínimo de $minimumContrast:1)',
];

/// O contraste do WCAG entre duas cores, de 1:1 a 21:1.
double contrastRatio(Color a, Color b) {
  final (la, lb) = (a.computeLuminance(), b.computeLuminance());
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
