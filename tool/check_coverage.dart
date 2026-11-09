// Confere a cobertura mínima das camadas com as regras do app, no papel do `coverageThreshold` do
// Jest no backend. Lê o relatório do `flutter test --coverage` e falha quando um grupo fica abaixo
// do mínimo (ver docs/TESTING.md):
//
//   fvm flutter test --coverage
//   fvm dart run tool/check_coverage.dart

import 'dart:io';

import 'package:meta/meta.dart';

/// A cobertura mínima de linhas de cada grupo, em porcentagem.
const minimumCoverage = 80;

const lcovPath = 'coverage/lcov.info';

/// Um grupo de arquivos de `lib/` com a cobertura conferida junta, como uma pasta do
/// `coverageThreshold` do Jest: um arquivo pouco testado pesa contra os outros do grupo.
final class CoverageGroup {
  const new(this.name, this.pattern);

  final String name;

  /// Os caminhos do grupo, relativos à raiz do projeto (ex.: `lib/features/auth/domain/...`).
  final RegExp pattern;
}

/// As camadas com as regras do app: o domínio, os dados, os ViewModels e o `AuthController`.
final coverageGroups = [
  CoverageGroup('domain/', RegExp('^lib/features/[^/]+/domain/')),
  CoverageGroup('data/', RegExp('^lib/features/[^/]+/data/')),
  CoverageGroup('ViewModels', RegExp('^lib/features/[^/]+/presentation/view_models/')),
  CoverageGroup('AuthController', RegExp('^lib/features/[^/]+/presentation/controllers/')),
];

/// As linhas de um arquivo que os testes podem cobrir ([found]) e as que eles cobriram ([hit]).
@immutable
final class FileCoverage {
  const new({required this.found, required this.hit});

  final int found;
  final int hit;

  /// A cobertura em porcentagem. Um arquivo sem linhas para cobrir conta como coberto.
  double get percent => found == 0 ? 100 : hit * 100 / found;

  FileCoverage operator +(FileCoverage other) =>
      FileCoverage(found: found + other.found, hit: hit + other.hit);

  @override
  bool operator ==(Object other) =>
      other is FileCoverage && other.found == found && other.hit == hit;

  @override
  int get hashCode => Object.hash(found, hit);

  @override
  String toString() => 'FileCoverage(hit: $hit, found: $found)';
}

/// A cobertura de cada arquivo do relatório [lcov], pelo caminho com `/`. Conta as linhas `DA:`
/// (linha e vezes que rodou): uma linha que aparece em mais de um registro conta uma vez só.
Map<String, FileCoverage> parseLcov(String lcov) {
  final lines = <String, Map<int, bool>>{};
  Map<int, bool>? current;

  for (final line in lcov.split('\n').map((line) => line.trim())) {
    if (line.startsWith('SF:')) {
      final path = line.substring('SF:'.length).replaceAll(r'\', '/');
      current = lines.putIfAbsent(path, () => {});
    } else if (line.startsWith('DA:') && current != null) {
      final [number, hits, ...] = line.substring('DA:'.length).split(',');
      final wasHit = int.parse(hits) > 0;
      current.update(int.parse(number), (hit) => hit || wasHit, ifAbsent: () => wasHit);
    } else if (line == 'end_of_record') {
      current = null;
    }
  }

  return {
    for (final MapEntry(key: path, value: hits) in lines.entries)
      path: FileCoverage(found: hits.length, hit: hits.values.where((hit) => hit).length),
  };
}

/// O resultado de um grupo: a cobertura somada dos [files] dele.
final class GroupResult {
  const new(this.group, this.files);

  final CoverageGroup group;
  final Map<String, FileCoverage> files;

  FileCoverage get total =>
      files.values.fold(const FileCoverage(found: 0, hit: 0), (total, file) => total + file);

  /// Um grupo sem nenhum arquivo no relatório também falha: o relatório saiu incompleto, ou o
  /// padrão do grupo deixou de achar os arquivos dele.
  bool get passes => files.isNotEmpty && total.percent >= minimumCoverage;
}

/// Separa os arquivos do relatório em cada um dos [groups].
List<GroupResult> checkCoverage(
  Map<String, FileCoverage> coverage, {
  List<CoverageGroup>? groups,
}) => [
  for (final group in groups ?? coverageGroups)
    GroupResult(group, {
      for (final MapEntry(key: path, value: file) in coverage.entries)
        if (group.pattern.hasMatch(path)) path: file,
    }),
];

/// O relatório para o terminal: uma linha por grupo e, nos que falharam, os arquivos do menos
/// coberto para o mais coberto.
String formatResults(List<GroupResult> results) {
  final output = StringBuffer('Cobertura de linhas (mínimo de $minimumCoverage% por grupo):\n');

  for (final result in results) {
    final FileCoverage(:hit, :found, :percent) = result.total;
    final status = result.passes ? 'ok' : 'abaixo do mínimo';
    final total = result.files.isEmpty ? '-' : _percent(percent);
    final lines = '($hit/$found)'.padRight(11);
    output.writeln('  ${result.group.name.padRight(15)} ${total.padLeft(6)}  $lines $status');

    if (result.passes) continue;
    if (result.files.isEmpty) {
      output.writeln('    nenhum arquivo do grupo no relatório');
      continue;
    }

    final files = result.files.entries.toList()
      ..sort((a, b) => a.value.percent.compareTo(b.value.percent));
    for (final MapEntry(key: path, value: file) in files) {
      output.writeln('    ${_percent(file.percent).padLeft(6)}  $path');
    }
  }

  return output.toString();
}

String _percent(double value) => '${value.toStringAsFixed(1).replaceAll('.', ',')}%';

void main() {
  final file = File(lcovPath);
  if (!file.existsSync()) {
    stderr.writeln('O $lcovPath não existe. Rode antes: fvm flutter test --coverage');
    exitCode = 1;
    return;
  }

  final results = checkCoverage(parseLcov(file.readAsStringSync()));
  stdout.write(formatResults(results));

  if (results.any((result) => !result.passes)) exitCode = 1;
}
