import 'package:reportaai_cm/features/account/domain/models/user_session.dart';

/// Um item do JSON do `GET /api/users/me/sessions` (exemplo no `FRONTEND.md` do backend).
final class UserSessionDto {
  const new({
    required this.id,
    required this.createdAt,
    required this.expiresAt,
    required this.current,
    this.ipAddress,
    this.userAgent,
  });

  /// Lança uma [FormatException] quando um campo falta ou está fora do formato. A mensagem diz só
  /// o nome do campo, nunca o valor, que pode ser o IP. O `callApi` a converte em
  /// `ServerException`.
  factory fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('Uma sessão da lista está fora do formato esperado.');
    }

    return UserSessionDto(
      id: _read(json, 'id'),
      createdAt: _readDateTime(json, 'createdAt'),
      expiresAt: _readDateTime(json, 'expiresAt'),
      ipAddress: _read(json, 'ipAddress'),
      userAgent: _read(json, 'userAgent'),
      current: _read(json, 'current'),
    );
  }

  /// A lista inteira. Lança a [FormatException] quando a resposta não é uma lista.
  static List<UserSessionDto> listFromJson(Object? json) {
    if (json is! List<Object?>) {
      throw const FormatException('A lista de sessões está fora do formato esperado.');
    }

    return [for (final item in json) UserSessionDto.fromJson(item)];
  }

  final String id;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? ipAddress;
  final String? userAgent;
  final bool current;

  UserSession toModel() => UserSession(
    id: id,
    createdAt: createdAt,
    expiresAt: expiresAt,
    ipAddress: ipAddress,
    userAgent: userAgent,
    current: current,
  );
}

/// O campo [key] com o tipo [T]. Com um [T] que aceita `null`, o campo ausente vira `null`.
T _read<T>(Map<String, Object?> json, String key) => switch (json[key]) {
  final T value => value,
  _ => throw _invalidField(key),
};

/// Uma data com hora, em ISO 8601. Fica em UTC, como veio.
DateTime _readDateTime(Map<String, Object?> json, String key) =>
    DateTime.tryParse(_read<String>(json, key)) ?? (throw _invalidField(key));

FormatException _invalidField(String key) =>
    FormatException('O campo "$key" de uma sessão está fora do formato esperado.');
