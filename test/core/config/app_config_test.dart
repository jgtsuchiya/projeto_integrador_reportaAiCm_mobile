import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    Matcher throwsConfigError(String messagePart) => throwsA(
      isA<AppConfigException>().having((error) => error.message, 'message', contains(messagePart)),
    );

    test('deve aceitar uma URL válida', () {
      final sut = AppConfig(apiUrl: 'http://10.0.2.2:3000');

      expect(sut.apiUrl, 'http://10.0.2.2:3000');
      expect(sut.apiBaseUrl, 'http://10.0.2.2:3000/api');
    });

    test('deve aceitar https e um caminho antes da API', () {
      final sut = AppConfig(apiUrl: 'https://reportaai.example.com/backend');

      expect(sut.apiBaseUrl, 'https://reportaai.example.com/backend/api');
    });

    test('deve remover os espaços e a barra do final', () {
      final sut = AppConfig(apiUrl: ' http://192.168.0.10:3000// ');

      expect(sut.apiUrl, 'http://192.168.0.10:3000');
    });

    test('deve recusar a URL ausente, dizendo como rodar o app', () {
      expect(() => AppConfig(apiUrl: ''), throwsConfigError('API_URL não foi definida'));
      expect(() => AppConfig(apiUrl: '   '), throwsConfigError('--dart-define-from-file'));
    });

    test('deve recusar uma URL inválida', () {
      for (final apiUrl in [
        'localhost:3000',
        '10.0.2.2:3000',
        'ftp://10.0.2.2:3000',
        'http://',
        'http://10.0.2.2:porta',
        'http://10.0.2.2:3000?debug=true',
      ]) {
        expect(() => AppConfig(apiUrl: apiUrl), throwsConfigError('não é um endereço válido'));
      }
    });

    test('deve recusar a URL terminada em /api, sugerindo o endereço certo', () {
      for (final apiUrl in [
        'http://10.0.2.2:3000/api',
        'http://10.0.2.2:3000/api/',
        'http://10.0.2.2:3000/API',
      ]) {
        expect(
          () => AppConfig(apiUrl: apiUrl),
          throwsConfigError('use "http://10.0.2.2:3000"'),
          reason: apiUrl,
        );
      }
    });

    test('deve aceitar um endereço que só começa com api', () {
      final sut = AppConfig(apiUrl: 'https://api.reportaai.example.com');

      expect(sut.apiBaseUrl, 'https://api.reportaai.example.com/api');
    });

    test('deve comparar pelo valor', () {
      expect(
        AppConfig(apiUrl: 'http://localhost:3000/'),
        AppConfig(apiUrl: 'http://localhost:3000'),
      );
    });
  });
}
