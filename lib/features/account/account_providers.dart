import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/core/network/dio_provider.dart';
import 'package:reportaai_cm/features/account/data/repositories/api_sessions_repository.dart';
import 'package:reportaai_cm/features/account/domain/repositories/sessions_repository.dart';

/// Liga o contrato à implementação. Os testes o trocam pelo `FakeSessionsRepository`.
final sessionsRepositoryProvider = Provider<SessionsRepository>(
  (ref) => ApiSessionsRepository(ref.watch(dioProvider)),
);
