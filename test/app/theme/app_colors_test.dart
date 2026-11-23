import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Confere que as cores ficam só em `lib/app/theme/`: as telas usam o `colorScheme`, a
/// `SuccessColors` ou o `AppColors`, e nunca uma cor fixa. Assim, uma troca de cor fica só no
/// tema, e o teste de contraste (`app_theme_test.dart`) confere todas.
void main() {
  group('Cores fixas fora de lib/app/theme/', () {
    final files = _readDartFiles('lib');

    test('deve encontrar os arquivos de lib/', () {
      expect(files, isNotEmpty);
    });

    test('nenhum arquivo fora de lib/app/theme/ deve ter Color(0x...) nem Colors.*', () {
      final found = findHardcodedColors(files);

      expect(found, isEmpty, reason: found.join('\n'));
    });
  });

  group('Verificação da busca', () {
    const view = 'lib/features/reports/presentation/views/reports_view.dart';

    test('deve acusar o Colors.red numa tela', () {
      expect(findHardcodedColors({view: 'Icon(Icons.close, color: Colors.red)'}), [
        '$view:1 → Colors.red',
      ]);
    });

    test('deve acusar a Color(0x...), o Color.fromARGB e o Color.fromRGBO', () {
      final found = findHardcodedColors({
        view:
            'const a = Color(0xFFE65100);\n'
            'final b = Color.fromARGB(255, 0, 0, 0);\n'
            'final c = Color.fromRGBO(0, 0, 0, 1);',
      });

      expect(found, ['$view:1 → Color(0x', '$view:2 → Color.fromARGB', '$view:3 → Color.fromRGBO']);
    });

    test('deve aceitar as cores em lib/app/theme/', () {
      expect(
        findHardcodedColors({
          'lib/app/theme/app_colors.dart': 'static const yellow = Color(0xFFFFBE00);',
          'lib/app/theme/app_theme.dart': 'onPrimary: Colors.white,',
        }),
        isEmpty,
      );
    });

    test('deve aceitar o colorScheme, a SuccessColors e o AppColors', () {
      expect(
        findHardcodedColors({
          view:
              'color: theme.colorScheme.primary,\n'
              'color: SuccessColors.of(context).success,\n'
              'backgroundColor: AppColors.photoBackdrop,',
        }),
        isEmpty,
      );
    });

    test('deve ignorar o comentário', () {
      expect(
        findHardcodedColors({
          view:
              '// O fundo era o Colors.black.\n'
              '/// Nunca use Color(0xFF000000) aqui.\n'
              'final a = 1; // e não o Colors.red',
        }),
        isEmpty,
      );
    });
  });
}

/// Uma cor fixa: a `Color(0x...)`, o `Color.fromARGB`, o `Color.fromRGBO` e as `Colors.*` (e as
/// `CupertinoColors.*`, que o teste de arquitetura já recusa pelo import).
final _hardcodedColor = RegExp(r'Color\(0x|Color\.fromARGB|Color\.fromRGBO|\bColors\.\w+');

/// O comentário do fim da linha (`//` e `///`). O `//` de uma URL, como `http://`, fica: vem
/// depois dos dois-pontos, e não de um espaço.
final _comment = RegExp(r'(^|\s)//.*$');

/// As cores fixas do [files] (caminho → código) fora de `lib/app/theme/`, como
/// "arquivo:linha → cor".
List<String> findHardcodedColors(Map<String, String> files) => [
  for (final MapEntry(key: file, value: source) in files.entries)
    if (!file.startsWith('lib/app/theme/'))
      for (final (index, line) in source.split('\n').indexed)
        for (final match in _hardcodedColor.allMatches(line.replaceFirst(_comment, '')))
          '$file:${index + 1} → ${match.group(0)}',
];

Map<String, String> _readDartFiles(String directory) => {
  for (final file in Directory(directory).listSync(recursive: true).whereType<File>())
    if (file.path.endsWith('.dart')) file.path.replaceAll(r'\', '/'): file.readAsStringSync(),
};
