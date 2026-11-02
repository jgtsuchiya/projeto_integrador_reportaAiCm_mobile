import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/localization.dart';
import 'package:reportaai_cm/app/router.dart';
import 'package:reportaai_cm/app/theme/app_theme.dart';

const appTitle = 'ReportaAi Cm';

/// O app: tema, idioma e rotas. Roda dentro do `ProviderScope` montado no `main`.
class App extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: appTitle,
      theme: AppTheme.light,
      // Sem themeMode, o padrão: claro ou escuro, junto com o sistema.
      darkTheme: AppTheme.dark,
      locale: appLocale,
      supportedLocales: const [appLocale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// O app não repete sozinho um provider que falhou: quem decide é a tela, com o "Tentar de
/// novo". O padrão do Riverpod 3 repetiria até 10 vezes qualquer exceção, como as da API.
Duration? noAutomaticRetry(int retryCount, Object error) => null;
