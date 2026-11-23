import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/account/domain/models/user_session.dart';

import '../../../../support/fake_sessions_repository.dart';

void main() {
  group('deviceOf', () {
    for (final (userAgent, kind, label) in [
      ('ReportaAiCm/0.1.0 (Android)', SessionDeviceKind.app, 'App ReportaAi (Android)'),
      ('ReportaAiCm/1.2.3 (iOS 17.4)', SessionDeviceKind.app, 'App ReportaAi (iOS 17.4)'),
      ('ReportaAiCm/0.1.0', SessionDeviceKind.app, 'App ReportaAi'),
      ('ReportaAiCm/0.1.0 ( )', SessionDeviceKind.app, 'App ReportaAi'),
      (
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
        SessionDeviceKind.browser,
        'Navegador',
      ),
      // O app de antes do User-Agent próprio, o `api.http` e o que vier sem o header.
      ('Dart/3.13 (dart:io)', SessionDeviceKind.unknown, 'Aparelho desconhecido'),
      ('vscode-restclient', SessionDeviceKind.unknown, 'Aparelho desconhecido'),
      ('', SessionDeviceKind.unknown, 'Aparelho desconhecido'),
      (null, SessionDeviceKind.unknown, 'Aparelho desconhecido'),
    ]) {
      test('deve ler "$userAgent" como "$label"', () {
        expect(deviceOf(userAgent), SessionDevice(kind, label));
      });
    }
  });

  group('SessionDevice', () {
    test('deve comparar pelo valor', () {
      const device = SessionDevice(SessionDeviceKind.browser, 'Navegador');

      expect(device, const SessionDevice(SessionDeviceKind.browser, 'Navegador'));
      expect(device.hashCode, const SessionDevice(SessionDeviceKind.browser, 'Navegador').hashCode);
      expect(device, isNot(const SessionDevice(SessionDeviceKind.unknown, 'Navegador')));
      expect(device.toString(), 'SessionDevice(browser, Navegador)');
    });
  });

  group('UserSession', () {
    test('deve ler o aparelho do user agent', () {
      expect(currentSession.device.label, 'App ReportaAi (Android)');
      expect(browserSession.device.kind, SessionDeviceKind.browser);
      expect(unknownSession.device.kind, SessionDeviceKind.unknown);
    });

    test('deve comparar pelo valor', () {
      final copy = UserSession(
        id: currentSession.id,
        createdAt: currentSession.createdAt,
        expiresAt: currentSession.expiresAt,
        ipAddress: currentSession.ipAddress,
        userAgent: currentSession.userAgent,
        current: currentSession.current,
      );

      expect(copy, currentSession);
      expect(copy.hashCode, currentSession.hashCode);
      expect(currentSession, isNot(browserSession));
    });

    test('não deve mostrar o IP nem o user agent no texto de log', () {
      final text = currentSession.toString();

      expect(text, isNot(contains('203.0.113.10')));
      expect(text, isNot(contains('ReportaAiCm')));
      expect(text, contains('id: sessao-deste-aparelho'));
      expect(unknownSession.toString(), contains('ipAddress: null'));
    });
  });
}
