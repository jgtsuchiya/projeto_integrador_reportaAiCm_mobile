// coverage:ignore-file
// Só monta o app: a lógica fica nas peças que ele chama, que têm os próprios testes.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/app/config_error_app.dart';
import 'package:reportaai_cm/app/localization.dart';
import 'package:reportaai_cm/core/auth/session_manager_provider.dart';
import 'package:reportaai_cm/core/auth/supertokens_session_manager.dart';
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

  // O SDK do SuperTokens é inicializado antes de qualquer chamada à API.
  final sessionManager = SuperTokensSessionManager.initialize(config);

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        sessionManagerProvider.overrideWithValue(sessionManager),
      ],
      retry: noAutomaticRetry,
      child: const App(),
    ),
  );
}
