import 'dart:async';

import 'package:reportaai_cm/features/auth/domain/models/client_registration.dart';
import 'package:reportaai_cm/features/auth/domain/models/registration_result.dart';
import 'package:reportaai_cm/features/auth/domain/repositories/registration_repository.dart';

/// Fake do [RegistrationRepository], escrito à mão como o `FakeIdentityProvider` do backend. Cada
/// teste define o resultado do próximo cadastro e confere os cadastros feitos em [calls].
final class FakeRegistrationRepository implements RegistrationRepository {
  /// Devolvido no próximo cadastro quando não há [error] nem [pending].
  RegistrationResult result = const RegistrationSuccess();

  /// Lançado no próximo cadastro, como o repositório real lança as exceções da API.
  Exception? error;

  /// Enquanto não é completado, o cadastro fica pendente: é o carregando do "Criar conta".
  Completer<RegistrationResult>? pending;

  /// Os dados de cada cadastro, na ordem, como iriam para a API.
  final calls = <ClientRegistration>[];

  @override
  Future<RegistrationResult> register(ClientRegistration registration) async {
    calls.add(registration);

    final pending = this.pending;
    if (pending != null) return await pending.future;

    final error = this.error;
    if (error != null) throw error;

    return result;
  }
}
