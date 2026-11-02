import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/app/localization.dart';
import 'package:reportaai_cm/app/theme/app_theme.dart';
import 'package:reportaai_cm/core/widgets/error_view.dart';

/// Abre no lugar do [App] quando a configuração do build é inválida (ex.: sem a `API_URL`), com
/// a mensagem do que falta. É o papel da validação de ambiente da API, que não sobe sem as
/// variáveis obrigatórias.
class ConfigErrorApp extends StatelessWidget {
  const new({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: appLocale,
      supportedLocales: const [appLocale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(
        body: SafeArea(
          child: ErrorView(title: 'Configuração incompleta', message: message),
        ),
      ),
    );
  }
}
