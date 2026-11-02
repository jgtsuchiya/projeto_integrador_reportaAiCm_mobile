import 'package:reportaai_cm/features/profile/domain/models/role.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_profile.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_status.dart';

/// O JSON do `GET /api/users/me` (exemplo no `FRONTEND.md` do backend). O `cpf`, o `phone` e o
/// `birthDate` só vêm para o Client.
final class UserProfileDto {
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

  /// Lança uma [FormatException] quando um campo falta ou está fora do formato. A mensagem diz só
  /// o nome do campo, nunca o valor, que pode ser o CPF (RM09). O `callApi` a converte em
  /// `ServerException`.
  factory fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('A resposta do GET /api/users/me está fora do formato esperado.');
    }

    return UserProfileDto(
      id: _read(json, 'id'),
      role: _read(json, 'role'),
      name: _read(json, 'name'),
      email: _read(json, 'email'),
      status: _read(json, 'status'),
      mfaEnabled: _read(json, 'mfaEnabled'),
      createdAt: _readDateTime(json, 'createdAt') ?? (throw _invalidField('createdAt')),
      updatedAt: _readDateTime(json, 'updatedAt') ?? (throw _invalidField('updatedAt')),
      emailVerifiedAt: _readDateTime(json, 'emailVerifiedAt'),
      lastLoginAt: _readDateTime(json, 'lastLoginAt'),
      cpf: _read(json, 'cpf'),
      phone: _read(json, 'phone'),
      birthDate: _readDate(json, 'birthDate'),
    );
  }

  final String id;

  /// O código da API: `CLIENT`, `ADMIN` ou `SUPER_ADMIN`.
  final String role;
  final String name;
  final String email;

  /// O código da API: `PENDING`, `ACTIVE` ou `INACTIVE`.
  final String status;
  final bool mfaEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? emailVerifiedAt;
  final DateTime? lastLoginAt;
  final String? cpf;
  final String? phone;
  final DateTime? birthDate;

  /// Um `role` ou um `status` que o app ainda não conhece vira o `unknown`, sem erro: o papel
  /// desconhecido não entra no app (RM01).
  UserProfile toModel() => UserProfile(
    id: id,
    role: switch (role) {
      'CLIENT' => Role.client,
      'ADMIN' => Role.admin,
      'SUPER_ADMIN' => Role.superAdmin,
      _ => Role.unknown,
    },
    name: name,
    email: email,
    status: switch (status) {
      'PENDING' => UserStatus.pending,
      'ACTIVE' => UserStatus.active,
      'INACTIVE' => UserStatus.inactive,
      _ => UserStatus.unknown,
    },
    mfaEnabled: mfaEnabled,
    createdAt: createdAt,
    updatedAt: updatedAt,
    emailVerifiedAt: emailVerifiedAt,
    lastLoginAt: lastLoginAt,
    cpf: cpf,
    phone: phone,
    birthDate: birthDate,
  );
}

final _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// O campo [key] com o tipo [T]. Com um [T] que aceita `null`, o campo ausente vira `null`.
T _read<T>(Map<String, Object?> json, String key) => switch (json[key]) {
  final T value => value,
  _ => throw _invalidField(key),
};

/// Uma data com hora, em ISO 8601 (ex.: `2026-10-04T23:57:35.427Z`). Fica em UTC, como veio.
DateTime? _readDateTime(Map<String, Object?> json, String key) =>
    switch (_read<String?>(json, key)) {
      null => null,
      final value => DateTime.tryParse(value) ?? (throw _invalidField(key)),
    };

/// Uma data sem hora (`AAAA-MM-DD`), à meia-noite no fuso do aparelho. Não passa pelo UTC: lida
/// como meia-noite UTC, a data voltaria um dia no `toLocal()` do Brasil (UTC-3).
DateTime? _readDate(Map<String, Object?> json, String key) {
  final value = _read<String?>(json, key);
  if (value == null) return null;

  if (_datePattern.firstMatch(value) case final match?) {
    final [year, month, day] = [for (var group = 1; group <= 3; group++) int.parse(match[group]!)];
    final date = DateTime(year, month, day);

    // Recusa as datas que o DateTime corrige sozinho, como 2001-02-30 (vira 2001-03-02).
    if (date.year == year && date.month == month && date.day == day) return date;
  }

  throw _invalidField(key);
}

FormatException _invalidField(String key) =>
    FormatException('O campo "$key" do GET /api/users/me está fora do formato esperado.');
