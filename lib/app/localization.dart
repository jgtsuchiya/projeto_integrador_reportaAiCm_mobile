import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Único idioma do app. Os textos ficam direto no código enquanto houver um idioma só.
const appLocale = Locale('pt', 'BR');

/// Prepara o `intl` para as datas e os números em pt-BR. Roda no `main`, antes do `runApp`, e
/// antes dos testes (`test/flutter_test_config.dart`).
Future<void> initializeLocalization() async {
  Intl.defaultLocale = appLocale.toString();
  await initializeDateFormatting(appLocale.toString());
}
