// coverage:ignore-file
// Só monta o app: a lógica fica nas peças que ele chama, que têm os próprios testes.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/app/config_error_app.dart';
import 'package:reportaai_cm/app/localization.dart';
import 'package:reportaai_cm/core/config/app_config.dart';
import 'package:reportaai_cm/core/config/app_config_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeLocalization();

  final AppConfig config;
  try {
    config = AppConfig.fromEnvironment();
  } on AppConfigException catch (error, stackTrace) {
    // Sem a configuração, o app não segue: mostra o que falta, na tela e no console.
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stackTrace, library: 'configuração do app'),
    );
    runApp(ConfigErrorApp(message: error.message));
    return;
  }

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      retry: noAutomaticRetry,
      child: const App(),
    ),
  );
}
