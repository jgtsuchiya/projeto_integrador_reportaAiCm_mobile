import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/core/auth/session_manager_provider.dart';
import 'package:reportaai_cm/core/network/dio_provider.dart';
import 'package:reportaai_cm/features/auth/data/repositories/api_auth_repository.dart';
import 'package:reportaai_cm/features/auth/domain/repositories/auth_repository.dart';

/// Liga o contrato à implementação, como o `auth.module.ts` do backend. Os testes trocam a
/// implementação por um fake com `authRepositoryProvider.overrideWithValue(...)`.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(ref.watch(dioProvider), ref.watch(sessionManagerProvider)),
);
