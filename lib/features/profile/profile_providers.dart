import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/core/network/dio_provider.dart';
import 'package:reportaai_cm/features/profile/data/repositories/api_profile_repository.dart';
import 'package:reportaai_cm/features/profile/domain/repositories/profile_repository.dart';

/// Liga o contrato à implementação, como o `users.module.ts` do backend. Os testes trocam a
/// implementação por um fake com `profileRepositoryProvider.overrideWithValue(...)`.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ApiProfileRepository(ref.watch(dioProvider)),
);
