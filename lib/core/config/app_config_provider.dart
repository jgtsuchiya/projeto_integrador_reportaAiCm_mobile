import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/core/config/app_config.dart';

/// A configuração validada na abertura. O `main` a fornece por override, e os testes também.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError(
    'O appConfigProvider não tem valor padrão: o main e os testes o fornecem por override.',
  ),
);
