import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/network/user_agent.dart';

void main() {
  group('buildUserAgent', () {
    test('deve levar só o nome do sistema no Android, em que o Dart devolve o kernel', () {
      final sut = buildUserAgent(
        appVersion: '0.1.0',
        operatingSystem: 'android',
        operatingSystemVersion: 'Linux 5.10.66-android12-9-00021-g2c152aa32942 #1 SMP PREEMPT',
      );

      expect(sut, 'ReportaAiCm/0.1.0 (Android)');
    });

    test('deve levar a versão do sistema no iOS', () {
      final sut = buildUserAgent(
        appVersion: '1.2.3',
        operatingSystem: 'ios',
        operatingSystemVersion: 'Version 17.4 (Build 21E213)',
      );

      expect(sut, 'ReportaAiCm/1.2.3 (iOS 17.4)');
    });

    test('deve levar só o nome do iOS quando a versão vem fora do formato', () {
      final sut = buildUserAgent(
        appVersion: '0.1.0',
        operatingSystem: 'ios',
        operatingSystemVersion: 'Versão desconhecida',
      );

      expect(sut, 'ReportaAiCm/0.1.0 (iOS)');
    });

    test('deve levar o nome cru de um sistema que o app não conhece', () {
      final sut = buildUserAgent(
        appVersion: '0.1.0',
        operatingSystem: 'haiku',
        operatingSystemVersion: 'R1',
      );

      expect(sut, 'ReportaAiCm/0.1.0 (haiku)');
    });

    test('deve usar os nomes dos sistemas de desktop', () {
      String of(String system) =>
          buildUserAgent(appVersion: '0.1.0', operatingSystem: system, operatingSystemVersion: '');

      expect(of('linux'), 'ReportaAiCm/0.1.0 (Linux)');
      expect(of('macos'), 'ReportaAiCm/0.1.0 (macOS)');
      expect(of('windows'), 'ReportaAiCm/0.1.0 (Windows)');
      expect(of('fuchsia'), 'ReportaAiCm/0.1.0 (Fuchsia)');
    });
  });

  test('o userAgentProvider não deve ter valor sem o override do main', () {
    final container = ProviderContainer.test();

    expect(container.read(userAgentProvider), isNull);
  });
}
