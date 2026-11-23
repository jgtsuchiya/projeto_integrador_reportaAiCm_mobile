import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Confere a regra de dependência entre as camadas (docs/ARCHITECTURE.md), no papel do
/// `no-restricted-imports` do ESLint no backend. Lê os imports e exports de cada arquivo de
/// `lib/` e falha com a lista dos que quebram uma regra.
void main() {
  group('Regra de dependência de lib/', () {
    final files = _readDartFiles('lib');

    test('deve encontrar os arquivos de lib/', () {
      expect(files, isNotEmpty);
    });

    for (final rule in architectureRules) {
      test(rule.description, () {
        final violations = findViolations(files, rule);

        expect(violations, isEmpty, reason: '${rule.description}\n${violations.join('\n')}');
      });
    }
  });

  group('Verificação das regras', () {
    List<String> violationsOf(String file, String import) => [
      for (final rule in architectureRules) ...findViolations({file: "import '$import';"}, rule),
    ];

    const view = 'lib/features/reports/presentation/views/reports_view.dart';
    const model = 'lib/features/reports/domain/models/report.dart';
    const repository = 'lib/features/reports/data/repositories/api_report_repository.dart';

    test('deve acusar a presentation importando a data', () {
      expect(
        violationsOf(view, 'package:reportaai_cm/features/reports/data/dtos/report_dto.dart'),
        hasLength(1),
      );
      expect(
        violationsOf(view, '../../data/repositories/api_report_repository.dart'),
        hasLength(1),
      );
    });

    test('deve acusar a presentation importando o Dio', () {
      expect(violationsOf(view, 'package:dio/dio.dart'), hasLength(1));
    });

    test('deve acusar o domain importando Flutter, Dio, Riverpod ou outras camadas', () {
      for (final import in [
        'package:flutter/foundation.dart',
        'package:material_ui/material_ui.dart',
        'package:dio/dio.dart',
        'package:flutter_riverpod/flutter_riverpod.dart',
        'dart:ui',
        '../../data/dtos/report_dto.dart',
        'package:reportaai_cm/features/reports/presentation/views/reports_view.dart',
        'package:reportaai_cm/core/network/api_exception.dart',
      ]) {
        expect(violationsOf(model, import), hasLength(1), reason: import);
      }
    });

    test('deve aceitar o domain importando só Dart, o meta e outros domínios', () {
      for (final import in [
        'dart:async',
        'package:meta/meta.dart',
        'report_status.dart',
        'package:reportaai_cm/features/profile/domain/models/user_profile.dart',
      ]) {
        expect(violationsOf(model, import), isEmpty, reason: import);
      }
    });

    test('deve acusar a data importando a presentation ou o Riverpod', () {
      expect(violationsOf(repository, '../../presentation/views/reports_view.dart'), hasLength(1));
      expect(
        violationsOf(repository, 'package:flutter_riverpod/flutter_riverpod.dart'),
        hasLength(1),
      );
    });

    test('deve acusar o core importando uma feature ou o app', () {
      const file = 'lib/core/widgets/error_view.dart';

      expect(violationsOf(file, '../../features/health/health_providers.dart'), hasLength(1));
      expect(violationsOf(file, 'package:reportaai_cm/app/router.dart'), hasLength(1));
    });

    test('deve acusar o SDK do SuperTokens fora do core/auth', () {
      for (final file in [
        view,
        repository,
        'lib/main.dart',
        'lib/core/network/dio_provider.dart',
      ]) {
        expect(
          violationsOf(file, 'package:supertokens_flutter/supertokens.dart'),
          hasLength(1),
          reason: file,
        );
      }
    });

    test('deve aceitar o SDK do SuperTokens no core/auth', () {
      expect(
        violationsOf(
          'lib/core/auth/supertokens_session_manager.dart',
          'package:supertokens_flutter/dio.dart',
        ),
        isEmpty,
      );
    });

    test('deve acusar o pacote do GPS fora do core/location', () {
      for (final file in [view, repository, 'lib/core/media/photo_capture.dart']) {
        for (final import in [
          'package:geolocator/geolocator.dart',
          'package:geolocator_platform_interface/geolocator_platform_interface.dart',
        ]) {
          expect(violationsOf(file, import), hasLength(1), reason: '$file → $import');
        }
      }
    });

    test('deve aceitar o pacote do GPS no core/location', () {
      expect(
        violationsOf(
          'lib/core/location/geolocator_location_service.dart',
          'package:geolocator/geolocator.dart',
        ),
        isEmpty,
      );
    });

    test('deve acusar os pacotes da câmera e da imagem fora do core/media', () {
      for (final file in [view, repository, 'lib/core/location/location_service.dart']) {
        for (final import in [
          'package:image_picker/image_picker.dart',
          'package:image_picker_platform_interface/image_picker_platform_interface.dart',
          'package:flutter_image_compress/flutter_image_compress.dart',
        ]) {
          expect(violationsOf(file, import), hasLength(1), reason: '$file → $import');
        }
      }
    });

    test('deve aceitar os pacotes da câmera e da imagem no core/media', () {
      expect(
        violationsOf(
          'lib/core/media/image_picker_photo_capture.dart',
          'package:image_picker/image_picker.dart',
        ),
        isEmpty,
      );
      expect(
        violationsOf(
          'lib/core/media/flutter_image_compressor.dart',
          'package:flutter_image_compress/flutter_image_compress.dart',
        ),
        isEmpty,
      );
    });

    test('deve acusar o Material do Flutter no lugar do material_ui', () {
      expect(violationsOf(view, 'package:flutter/material.dart'), hasLength(1));
      expect(violationsOf(view, 'package:flutter/cupertino.dart'), hasLength(1));
    });

    test('deve ler o import com aspas duplas, com show e o export', () {
      final violations = findViolations({
        view:
            'import "package:dio/dio.dart" show Dio;\n'
            "export 'package:reportaai_cm/features/reports/data/dtos/report_dto.dart';",
      }, architectureRules.first);

      expect(violations, hasLength(2));
    });

    test('deve ignorar o import comentado', () {
      expect(
        findViolations({view: "// import 'package:dio/dio.dart';"}, architectureRules.first),
        isEmpty,
      );
    });
  });
}

/// Uma regra: os arquivos a que ela vale e os imports que eles não podem ter. Os imports chegam
/// resolvidos: os do próprio app viram caminhos de `lib/` (ex.: `lib/core/...`), e os outros
/// ficam como estão (`dart:...` e `package:...`).
final class ArchitectureRule {
  const new({required this.description, required this.appliesTo, required this.isForbidden});

  final String description;
  final bool Function(String file) appliesTo;
  final bool Function(String import) isForbidden;
}

final architectureRules = [
  ArchitectureRule(
    description: 'presentation/ não importa data/ nem o Dio: só o contrato e os providers',
    appliesTo: (file) => _isLayer(file, 'presentation'),
    isForbidden: (import) => _isLayer(import, 'data') || import.startsWith('package:dio/'),
  ),
  ArchitectureRule(
    description: 'domain/ só importa Dart, o package:meta e outros arquivos de domain/',
    appliesTo: (file) => _isLayer(file, 'domain'),
    isForbidden: (import) =>
        !(_isDartLibrary(import) ||
            import.startsWith('package:meta/') ||
            _isLayer(import, 'domain')),
  ),
  ArchitectureRule(
    description: 'data/ não importa presentation/ nem o Riverpod: a ligação fica nos providers',
    appliesTo: (file) => _isLayer(file, 'data'),
    isForbidden: (import) =>
        _isLayer(import, 'presentation') || _isPackage(import, ['riverpod', 'flutter_riverpod']),
  ),
  ArchitectureRule(
    description: 'core/ não importa features/ nem app/: é o código compartilhado por todos',
    appliesTo: (file) => file.startsWith('lib/core/'),
    isForbidden: (import) => import.startsWith('lib/features/') || import.startsWith('lib/app/'),
  ),
  ArchitectureRule(
    description:
        'só o core/auth/ importa o SDK do SuperTokens: o resto do app usa o SessionManager',
    appliesTo: (file) => !file.startsWith('lib/core/auth/'),
    isForbidden: (import) => _isPackage(import, ['supertokens_flutter']),
  ),
  ArchitectureRule(
    description:
        'só o core/location/ importa o pacote do GPS: o resto do app usa o LocationService',
    appliesTo: (file) => !file.startsWith('lib/core/location/'),
    // O `geolocator` e os pacotes dele (`geolocator_android`, `geolocator_platform_interface`...).
    isForbidden: (import) => import.startsWith('package:geolocator'),
  ),
  ArchitectureRule(
    description:
        'só o core/media/ importa os pacotes da câmera e da imagem: o resto do app usa o '
        'PhotoCapture e o ImageCompressor',
    appliesTo: (file) => !file.startsWith('lib/core/media/'),
    // Os dois pacotes e os deles (`image_picker_android`, `flutter_image_compress_common`...).
    isForbidden: (import) =>
        import.startsWith('package:image_picker') ||
        import.startsWith('package:flutter_image_compress'),
  ),
  ArchitectureRule(
    description: 'o Material vem do material_ui, não do package:flutter/material.dart',
    appliesTo: (file) => true,
    isForbidden: (import) =>
        import == 'package:flutter/material.dart' || import == 'package:flutter/cupertino.dart',
  ),
];

const _appPackage = 'package:reportaai_cm/';

final _directive = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);

/// Os imports do [files] (caminho → código) que a [rule] proíbe, como "arquivo → import".
List<String> findViolations(Map<String, String> files, ArchitectureRule rule) => [
  for (final MapEntry(key: file, value: source) in files.entries)
    if (rule.appliesTo(file))
      for (final match in _directive.allMatches(source))
        if (rule.isForbidden(_resolve(file, match.group(1)!))) '$file → ${match.group(1)}',
];

String _resolve(String file, String import) {
  if (import.startsWith(_appPackage)) return 'lib/${import.substring(_appPackage.length)}';
  if (import.startsWith('package:') || import.startsWith('dart:')) return import;

  return Uri(path: file).resolve(import).path;
}

bool _isLayer(String path, String layer) => RegExp('^lib/features/[^/]+/$layer/').hasMatch(path);

bool _isDartLibrary(String import) => import.startsWith('dart:') && import != 'dart:ui';

bool _isPackage(String import, List<String> packages) =>
    packages.any((package) => import.startsWith('package:$package/'));

Map<String, String> _readDartFiles(String directory) => {
  for (final file in Directory(directory).listSync(recursive: true).whereType<File>())
    if (file.path.endsWith('.dart')) file.path.replaceAll(r'\', '/'): file.readAsStringSync(),
};
