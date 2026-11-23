import 'package:flutter_riverpod/flutter_riverpod.dart';

/// O nome do app no `User-Agent`, o primeiro pedaço: `ReportaAiCm/0.1.0 (Android)`.
const userAgentProduct = 'ReportaAiCm';

/// O `User-Agent` das chamadas à API. O `main` o fornece por override, com a versão do app e o
/// sistema do aparelho ([buildUserAgent]). Sem ele, como nos testes, o `Dio` manda o padrão do
/// `dart:io`.
final userAgentProvider = Provider<String?>((ref) => null);

/// Um número de versão, como o `17.4` do `Version 17.4 (Build 21E213)` do iOS.
final _versionNumber = RegExp(r'\d+(\.\d+)*');

/// O `User-Agent` do app: `ReportaAiCm/<versão> (<sistema> <versão do sistema>)`, como
/// `ReportaAiCm/0.1.0 (iOS 17.4)`. A API o grava em cada login, e a lista de sessões abertas o
/// mostra como "App ReportaAi (iOS 17.4)".
///
/// O [operatingSystem] e o [operatingSystemVersion] são os do `Platform` do `dart:io`. A versão
/// do sistema só entra no iOS e no macOS, em que o Dart devolve a versão do produto. No Android e
/// no Linux, ele devolve a do kernel (`Linux 5.10.66-android12-9-...`), que não diz a versão do
/// sistema para o usuário: o `User-Agent` leva só o nome do sistema, `(Android)`.
String buildUserAgent({
  required String appVersion,
  required String operatingSystem,
  required String operatingSystemVersion,
}) {
  final system = switch (operatingSystem) {
    'android' => 'Android',
    'ios' => 'iOS',
    'macos' => 'macOS',
    'linux' => 'Linux',
    'windows' => 'Windows',
    'fuchsia' => 'Fuchsia',
    _ => operatingSystem,
  };
  final systemVersion = switch (operatingSystem) {
    'ios' || 'macos' => _versionNumber.firstMatch(operatingSystemVersion)?.group(0),
    _ => null,
  };

  return '$userAgentProduct/$appVersion (${[system, ?systemVersion].join(' ')})';
}
