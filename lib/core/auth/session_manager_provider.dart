import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/core/auth/session_manager.dart';

/// A sessão do usuário. O `main` a fornece por override, com o SDK do SuperTokens já
/// inicializado, e os testes, com o `FakeSessionManager`.
final sessionManagerProvider = Provider<SessionManager>(
  (ref) => throw UnimplementedError(
    'O sessionManagerProvider não tem valor padrão: o main e os testes o fornecem por override.',
  ),
);
