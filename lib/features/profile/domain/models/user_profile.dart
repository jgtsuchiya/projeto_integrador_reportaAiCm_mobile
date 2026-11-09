import 'package:meta/meta.dart';
import 'package:reportaai_cm/features/profile/domain/models/role.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_status.dart';

/// O perfil do usuário logado, do `GET /api/users/me`. É por ele que o app sabe quem entrou e com
/// qual papel (RM01). As datas com hora estão em UTC, como a API as devolve: para mostrar no
/// horário do aparelho, use o `toLocal()`.
@immutable
final class UserProfile {
  const new({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    required this.status,
    required this.mfaEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.emailVerifiedAt,
    this.lastLoginAt,
    this.cpf,
    this.phone,
    this.birthDate,
  });

  final String id;
  final Role role;
  final String name;
  final String email;
  final UserStatus status;

  /// Se o login da conta pede o código da verificação em duas etapas (RN24).
  final bool mfaEnabled;

  final DateTime createdAt;

  /// No Client, a alteração mais recente entre a conta e o perfil.
  final DateTime updatedAt;

  /// `null` até o Client confirmar o e-mail. No ADM e no SuperAdm, vem sempre preenchido.
  final DateTime? emailVerifiedAt;

  final DateTime? lastLoginAt;

  /// Só do Client. Completo, só com dígitos: a tela o mostra mascarado, e ele nunca vai para log
  /// nem para mensagem de erro (RM09).
  final String? cpf;

  /// Só do Client. Só com dígitos: o DDD e o número, de 8 dígitos no fixo e 9 no celular.
  final String? phone;

  /// Só do Client. Uma data sem hora, à meia-noite no fuso do aparelho: o `formatDate` mostra o
  /// mesmo dia em qualquer fuso, e o `toLocal()` não a muda.
  final DateTime? birthDate;

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.id == id &&
      other.role == role &&
      other.name == name &&
      other.email == email &&
      other.status == status &&
      other.mfaEnabled == mfaEnabled &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.emailVerifiedAt == emailVerifiedAt &&
      other.lastLoginAt == lastLoginAt &&
      other.cpf == cpf &&
      other.phone == phone &&
      other.birthDate == birthDate;

  @override
  int get hashCode => Object.hash(
    id,
    role,
    name,
    email,
    status,
    mfaEnabled,
    createdAt,
    updatedAt,
    emailVerifiedAt,
    lastLoginAt,
    cpf,
    phone,
    birthDate,
  );

  @override
  String toString() =>
      'UserProfile(id: $id, role: ${role.name}, name: $name, email: $email, '
      'status: ${status.name}, mfaEnabled: $mfaEnabled, createdAt: $createdAt, '
      'updatedAt: $updatedAt, emailVerifiedAt: $emailVerifiedAt, lastLoginAt: $lastLoginAt, '
      // O CPF nunca vai para log (RM09).
      'cpf: ${cpf == null ? null : '***'}, phone: $phone, birthDate: $birthDate)';
}
