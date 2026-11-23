import 'dart:async';

import 'package:reportaai_cm/features/profile/domain/models/profile_changes.dart';
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
/// o e-mail ([emailVerifiedAt]) ou de salvar os dados.
UserProfile clientProfileWith({
  String? name,
  String? phone,
  DateTime? birthDate,
  DateTime? emailVerifiedAt,
  bool? mfaEnabled,
}) => UserProfile(
  id: clientProfile.id,
  role: clientProfile.role,
  name: name ?? clientProfile.name,
  email: clientProfile.email,
  status: clientProfile.status,
  mfaEnabled: mfaEnabled ?? clientProfile.mfaEnabled,
  lastLoginAt: clientProfile.lastLoginAt,
  createdAt: clientProfile.createdAt,
  updatedAt: clientProfile.updatedAt,
  emailVerifiedAt: emailVerifiedAt ?? clientProfile.emailVerifiedAt,
  cpf: clientProfile.cpf,
  phone: phone ?? clientProfile.phone,
  birthDate: birthDate ?? clientProfile.birthDate,
);

/// O e-mail confirmado do [clientProfileWith], para as telas que exigem a confirmação.
final emailVerifiedAt = DateTime.utc(2026, 10, 5, 10);

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
/// teste define o resultado da próxima chamada e confere quantas foram feitas em [calls] (o
/// `GET /api/users/me`) e em [resendCalls] (o reenvio do link de confirmação), e o que foi
/// enviado nas listas das outras chamadas.
///
/// A edição dos dados e a verificação em duas etapas devolvem o [result] com as mudanças, e o
/// guardam como o perfil seguinte, como a API.
final class FakeProfileRepository implements ProfileRepository {
  /// Devolvido quando não há [error] nem [pending].
  UserProfile result = clientProfile;

  /// Lançado na próxima chamada, como o repositório real lança as exceções da API.
  Exception? error;

  /// Enquanto não é completado, a chamada fica pendente: é o estado de carregando da tela.
  Completer<UserProfile>? pending;

  int calls = 0;

  /// Lançado no próximo reenvio do link de confirmação, como a `BusinessRuleException` do 422.
  Exception? resendError;

  /// Enquanto não é completado, o reenvio fica pendente: é o "Enviando" do aviso.
  Completer<void>? resendPending;

  int resendCalls = 0;

  /// Lançado na próxima edição dos dados, como a `ValidationException` do 400.
  Exception? updateError;

  /// Enquanto não é completado, a edição dos dados fica pendente.
  Completer<void>? updatePending;

  /// As mudanças de cada edição dos dados, na ordem.
  final updateCalls = <ProfileChanges>[];

  /// Lançado na próxima troca de senha, como a `BusinessRuleException` da senha atual errada.
  Exception? changePasswordError;

  /// Enquanto não é completado, a troca de senha fica pendente.
  Completer<void>? changePasswordPending;

  final changePasswordCalls = <({String currentPassword, String newPassword})>[];

  /// Lançado na próxima mudança da verificação em duas etapas.
  Exception? setMfaError;

  /// Enquanto não é completado, a mudança da verificação em duas etapas fica pendente.
  Completer<void>? setMfaPending;

  final setMfaCalls = <({bool enabled, String password})>[];

  /// Lançado na próxima exclusão da conta.
  Exception? deleteAccountError;

  /// Enquanto não é completado, a exclusão da conta fica pendente.
  Completer<void>? deleteAccountPending;

  /// A senha de cada exclusão da conta, na ordem.
  final deleteAccountCalls = <String>[];

  @override
  Future<UserProfile> updateMe(ProfileChanges changes) async {
    updateCalls.add(changes);
    await _settle(updatePending, updateError);

    return result = UserProfile(
      id: result.id,
      role: result.role,
      name: changes.name?.trim() ?? result.name,
      email: result.email,
      status: result.status,
      mfaEnabled: result.mfaEnabled,
      createdAt: result.createdAt,
      updatedAt: result.updatedAt,
      emailVerifiedAt: result.emailVerifiedAt,
      lastLoginAt: result.lastLoginAt,
      cpf: result.cpf,
      phone: changes.phone ?? result.phone,
      birthDate: switch (changes.birthDate) {
        final date? => DateTime.parse(date),
        null => result.birthDate,
      },
    );
  }

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) {
    changePasswordCalls.add((currentPassword: currentPassword, newPassword: newPassword));
    return _settle(changePasswordPending, changePasswordError);
  }

  @override
  Future<UserProfile> setMfa({required bool enabled, required String password}) async {
    setMfaCalls.add((enabled: enabled, password: password));
    await _settle(setMfaPending, setMfaError);

    return result = UserProfile(
      id: result.id,
      role: result.role,
      name: result.name,
      email: result.email,
      status: result.status,
      mfaEnabled: enabled,
      createdAt: result.createdAt,
      updatedAt: result.updatedAt,
      emailVerifiedAt: result.emailVerifiedAt,
      lastLoginAt: result.lastLoginAt,
      cpf: result.cpf,
      phone: result.phone,
      birthDate: result.birthDate,
    );
  }

  @override
  Future<void> deleteAccount({required String password}) {
    deleteAccountCalls.add(password);
    return _settle(deleteAccountPending, deleteAccountError);
  }

  /// Espera o [pending], se houver, e lança o [error], se houver.
  Future<void> _settle(Completer<void>? pending, Exception? error) async {
    if (pending != null) await pending.future;
    if (error != null) throw error;
  }

  @override
  Future<void> resendEmailVerification() async {
    resendCalls++;

    final pending = resendPending;
    if (pending != null) await pending.future;

    final error = resendError;
    if (error != null) throw error;
  }

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
