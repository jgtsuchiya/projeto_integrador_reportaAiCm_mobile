import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/config_error_app.dart';
import 'package:reportaai_cm/core/config/app_config.dart';

void main() {
  group('ConfigErrorApp', () {
    testWidgets('deve mostrar a mensagem do AppConfig, sem o "Tentar de novo"', (tester) async {
      final error = () {
        try {
          AppConfig(apiUrl: '');
        } on AppConfigException catch (error) {
          return error;
        }
        fail('A configuração vazia deveria ser recusada.');
      }();

      await tester.pumpWidget(ConfigErrorApp(message: error.message));

      expect(find.text('Configuração incompleta'), findsOneWidget);
      expect(find.text(error.message), findsOneWidget);
      expect(find.text('Tentar de novo'), findsNothing);
    });
  });
}
