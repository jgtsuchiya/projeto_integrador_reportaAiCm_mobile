import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/app/localization.dart';
import 'package:reportaai_cm/app/theme/app_theme.dart';
import 'package:reportaai_cm/core/config/app_config.dart';
import 'package:reportaai_cm/core/config/app_config_provider.dart';

/// Configuração dos testes que não definem a própria.
final testConfig = AppConfig(apiUrl: 'http://localhost:3000');

extension PumpApp on WidgetTester {
  /// Monta o [widget] como uma tela do app: `ProviderScope` (com a [config] e os [overrides]),
  /// tema e idioma pt-BR, sem as rotas. Um componente solto precisa de um `Scaffold` em volta.
  Future<void> pumpApp(
    Widget widget, {
    List<Override> overrides = const [],
    AppConfig? config,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return pumpWidget(
      _scope(
        overrides: overrides,
        config: config,
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          locale: appLocale,
          supportedLocales: const [appLocale],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: widget,
        ),
      ),
    );
  }

  /// Como o [pumpApp], mas com as rotas do [router] (ex.: o `createRouter`).
  Future<void> pumpRouter(
    GoRouter router, {
    List<Override> overrides = const [],
    AppConfig? config,
  }) {
    return pumpWidget(
      _scope(
        overrides: overrides,
        config: config,
        child: MaterialApp.router(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          locale: appLocale,
          supportedLocales: const [appLocale],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: router,
        ),
      ),
    );
  }

  /// Tela de um celular pequeno (360 x 640) com a fonte do sistema na [textScale], para conferir
  /// que nada é cortado. Tudo volta ao padrão no fim do teste.
  void usePhoneScreen({double textScale = 1}) {
    view
      ..physicalSize = const Size(1080, 1920)
      ..devicePixelRatio = 3;
    platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(view.reset);
    addTearDown(platformDispatcher.clearTextScaleFactorTestValue);
  }
}

ProviderScope _scope({
  required List<Override> overrides,
  required AppConfig? config,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [appConfigProvider.overrideWithValue(config ?? testConfig), ...overrides],
    retry: noAutomaticRetry,
    child: child,
  );
}
