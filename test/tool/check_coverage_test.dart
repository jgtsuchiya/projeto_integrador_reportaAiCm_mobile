import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_coverage.dart';

/// Um registro do lcov, como o `flutter test --coverage` escreve: o arquivo e as linhas `DA:`
/// (linha e vezes que rodou), com a soma no `LF` e no `LH`.
String _record(String path, Map<int, int> hits) => [
  'SF:$path',
  for (final MapEntry(key: line, value: count) in hits.entries) 'DA:$line,$count',
  'LF:${hits.length}',
  'LH:${hits.values.where((count) => count > 0).length}',
  'end_of_record',
].join('\n');

const _domain = 'lib/features/auth/domain/models/email.dart';
const _data = 'lib/features/auth/data/repositories/api_auth_repository.dart';
const _viewModel = 'lib/features/auth/presentation/view_models/login_view_model.dart';
const _controller = 'lib/features/auth/presentation/controllers/auth_controller.dart';
const _view = 'lib/features/auth/presentation/views/login_view.dart';

void main() {
  group('parseLcov', () {
    test('deve contar as linhas encontradas e as cobertas de cada arquivo', () {
      final lcov = [
        _record(_domain, {1: 3, 2: 0, 3: 1, 4: 1}),
        _record(_data, {10: 0, 11: 0}),
      ].join('\n');

      final sut = parseLcov(lcov);

      expect(sut, {
        _domain: const FileCoverage(found: 4, hit: 3),
        _data: const FileCoverage(found: 2, hit: 0),
      });
    });

    test('deve contar uma vez a linha que aparece em mais de um registro do arquivo', () {
      final lcov = [
        _record(_domain, {1: 0, 2: 0}),
        _record(_domain, {2: 5, 3: 0}),
      ].join('\n');

      final sut = parseLcov(lcov);

      expect(sut[_domain], const FileCoverage(found: 3, hit: 1));
    });

    test(r'deve ler o caminho com \ do Windows e o fim de linha \r\n', () {
      final lcov = _record(r'lib\features\auth\domain\models\email.dart', {1: 1, 2: 0});

      final sut = parseLcov(lcov.replaceAll('\n', '\r\n'));

      expect(sut, {_domain: const FileCoverage(found: 2, hit: 1)});
    });
  });

  group('FileCoverage', () {
    test('deve calcular a porcentagem e contar como coberto o arquivo sem linhas', () {
      expect(const FileCoverage(found: 4, hit: 3).percent, 75);
      expect(const FileCoverage(found: 0, hit: 0).percent, 100);
    });
  });

  group('checkCoverage', () {
    test('deve separar o domínio, os dados, os ViewModels e o AuthController', () {
      final coverage = {
        for (final path in [_domain, _data, _viewModel, _controller, _view])
          path: const FileCoverage(found: 10, hit: 10),
      };

      final sut = checkCoverage(coverage);

      expect(
        {for (final result in sut) result.group.name: result.files.keys},
        {
          'domain/': [_domain],
          'data/': [_data],
          'ViewModels': [_viewModel],
          'AuthController': [_controller],
        },
      );
    });

    test('deve somar as linhas dos arquivos do grupo', () {
      final coverage = {
        _domain: const FileCoverage(found: 10, hit: 10),
        'lib/features/profile/domain/models/user_profile.dart': const FileCoverage(
          found: 10,
          hit: 5,
        ),
      };

      final [sut, ...] = checkCoverage(coverage);

      expect(sut.total, const FileCoverage(found: 20, hit: 15));
      expect(sut.total.percent, 75);
      expect(sut.passes, isFalse);
    });

    test('deve aceitar o grupo no mínimo de $minimumCoverage%', () {
      final coverage = {_domain: const FileCoverage(found: 100, hit: minimumCoverage)};

      final [sut, ...] = checkCoverage(coverage);

      expect(sut.passes, isTrue);
    });

    test('deve recusar o grupo sem nenhum arquivo no relatório', () {
      final [sut, ...] = checkCoverage({});

      expect(sut.passes, isFalse);
    });
  });

  group('formatResults', () {
    test('deve listar os arquivos do grupo abaixo do mínimo, do menos coberto ao mais', () {
      const covered = 'lib/features/profile/domain/models/user_profile.dart';
      final results = checkCoverage({
        covered: const FileCoverage(found: 10, hit: 9),
        _domain: const FileCoverage(found: 10, hit: 2),
        _data: const FileCoverage(found: 10, hit: 10),
      });

      final sut = formatResults(results);

      expect(sut, contains('domain/          55,0%  (11/20)     abaixo do mínimo'));
      expect(sut, contains('data/           100,0%  (10/10)     ok'));
      expect(sut.indexOf('20,0%  $_domain'), lessThan(sut.indexOf('90,0%  $covered')));
      expect(sut, contains('ViewModels           -  (0/0)       abaixo do mínimo'));
      expect(sut, contains('nenhum arquivo do grupo no relatório'));
    });
  });
}
