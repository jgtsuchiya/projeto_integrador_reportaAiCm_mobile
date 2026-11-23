// coverage:ignore-file
// Só monta o app: a lógica fica nas peças que ele chama, que têm os próprios testes.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/app/config_error_app.dart';
import 'package:reportaai_cm/app/localization.dart';
import 'package:reportaai_cm/core/auth/session_manager_provider.dart';
import 'package:reportaai_cm/core/auth/supertokens_session_manager.dart';
import 'package:reportaai_cm/core/config/app_config.dart';
import 'package:reportaai_cm/core/config/app_config_provider.dart';
import 'package:reportaai_cm/core/network/user_agent.dart';

Future<void> main() => startApp();

/// Lê o ambiente, inicializa e roda o app. Os testes de integração passam nos [overrides] o que
/// não dá para usar de verdade fora do aparelho, como a câmera e o GPS (ver o
/// `integration_test/reports_flow_test.dart`).
Future<void> startApp({List<Override> overrides = const []}) async {
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
  final userAgent = await _userAgent();

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        sessionManagerProvider.overrideWithValue(sessionManager),
        userAgentProvider.overrideWithValue(userAgent),
        ...overrides,
      ],
      retry: noAutomaticRetry,
      child: const App(),
    ),
  );
}

/// O `User-Agent` do app, com a versão do `pubspec.yaml`, para a lista de sessões abertas. Sem a
/// versão (o plugin falhou), vale o padrão do `dart:io`: o app abre do mesmo jeito.
Future<String?> _userAgent() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return buildUserAgent(
      appVersion: info.version,
      operatingSystem: Platform.operatingSystem,
      operatingSystemVersion: Platform.operatingSystemVersion,
    );
  } on Object {
    return null;
  }
}
