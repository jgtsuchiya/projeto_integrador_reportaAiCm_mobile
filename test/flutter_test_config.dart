import 'dart:async';

import 'package:reportaai_cm/app/localization.dart';

/// Roda antes dos testes de `test/`: prepara as datas em pt-BR do `intl`, como o `main`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeLocalization();
  await testMain();
}
