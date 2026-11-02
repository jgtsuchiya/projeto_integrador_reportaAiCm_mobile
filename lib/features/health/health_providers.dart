import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reportaai_cm/core/network/dio_provider.dart';
import 'package:reportaai_cm/features/health/data/repositories/api_health_repository.dart';
import 'package:reportaai_cm/features/health/domain/repositories/health_repository.dart';

/// Liga o contrato à implementação, como o `health.module.ts` do backend. É o único arquivo da
/// feature que a `presentation` usa para chegar à camada de dados. Os testes trocam a
/// implementação por um fake com `healthRepositoryProvider.overrideWithValue(...)`.
final healthRepositoryProvider = Provider<HealthRepository>(
  (ref) => ApiHealthRepository(ref.watch(dioProvider)),
);
