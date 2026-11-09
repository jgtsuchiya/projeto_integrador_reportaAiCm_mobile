import 'dart:async';

import 'package:reportaai_cm/features/profile/domain/models/role.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_profile.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_status.dart';
import 'package:reportaai_cm/features/profile/domain/repositories/profile_repository.dart';

/// O Client do exemplo do `FRONTEND.md` do backend, como o `GET /api/users/me` o devolve.
const clientProfileJson = <String, Object?>{
  'id': '48550ab5-e0ae-44e9-a646-997c89a9fdb4',
  'role': 'CLIENT',
  'name': 'Maria da Silva',
  'email': 'maria.silva@exemplo.com',
  'status': 'ACTIVE',
  'emailVerifiedAt': null,
  'mfaEnabled': false,
  'lastLoginAt': '2026-10-04T23:57:35.427Z',
  'createdAt': '2026-10-04T23:57:35.237Z',
  'updatedAt': '2026-10-04T23:57:35.237Z',
  'cpf': '52998224725',
  'phone': '44999998888',
  'birthDate': '1990-05-20',
};

/// O [clientProfileJson] como modelo.
final clientProfile = UserProfile(
  id: '48550ab5-e0ae-44e9-a646-997c89a9fdb4',
  role: Role.client,
  name: 'Maria da Silva',
  email: 'maria.silva@exemplo.com',
  status: UserStatus.active,
  mfaEnabled: false,
  lastLoginAt: DateTime.utc(2026, 10, 4, 23, 57, 35, 427),
  createdAt: DateTime.utc(2026, 10, 4, 23, 57, 35, 237),
  updatedAt: DateTime.utc(2026, 10, 4, 23, 57, 35, 237),
  cpf: '52998224725',
  phone: '44999998888',
  birthDate: DateTime(1990, 5, 20),
);

/// O [clientProfile] com os campos trocados, como o perfil que volta depois de o Client confirmar
/// o e-mail ([emailVerifiedAt]).
UserProfile clientProfileWith({String? name, String? phone, DateTime? emailVerifiedAt}) =>
    UserProfile(
      id: clientProfile.id,
      role: clientProfile.role,
      name: name ?? clientProfile.name,
      email: clientProfile.email,
      status: clientProfile.status,
      mfaEnabled: clientProfile.mfaEnabled,
      lastLoginAt: clientProfile.lastLoginAt,
      createdAt: clientProfile.createdAt,
      updatedAt: clientProfile.updatedAt,
      emailVerifiedAt: emailVerifiedAt ?? clientProfile.emailVerifiedAt,
      cpf: clientProfile.cpf,
      phone: phone ?? clientProfile.phone,
      birthDate: clientProfile.birthDate,
    );

/// Um ADM, que não entra no app (RM01): sem os campos do Client e com o e-mail confirmado.
final adminProfile = UserProfile(
  id: '7d0c2a8e-5b1f-4f0e-9a51-1c3f2b6d8e90',
  role: Role.admin,
  name: 'Ana Souza',
  email: 'ana.souza@exemplo.com',
  status: UserStatus.active,
  mfaEnabled: false,
  emailVerifiedAt: DateTime.utc(2026, 9, 1, 12),
  createdAt: DateTime.utc(2026, 9, 1, 12),
  updatedAt: DateTime.utc(2026, 9, 1, 12),
);

/// Fake do [ProfileRepository], escrito à mão como o `FakeIdentityProvider` do backend. Cada
/// teste define o resultado da próxima chamada e confere quantas foram feitas em [calls].
final class FakeProfileRepository implements ProfileRepository {
  /// Devolvido quando não há [error] nem [pending].
  UserProfile result = clientProfile;

  /// Lançado na próxima chamada, como o repositório real lança as exceções da API.
  Exception? error;

  /// Enquanto não é completado, a chamada fica pendente: é o estado de carregando da tela.
  Completer<UserProfile>? pending;

  int calls = 0;

  @override
  Future<UserProfile> getMe() {
    calls++;

    final pending = this.pending;
    if (pending != null) return pending.future;

    final error = this.error;
    if (error != null) return Future.error(error);

    return Future.value(result);
  }
}
