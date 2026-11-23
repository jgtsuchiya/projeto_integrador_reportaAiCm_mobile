import 'package:meta/meta.dart';

/// Uma sessão aberta da conta, da lista do `GET /api/users/me/sessions` (RM19). As datas estão em
/// UTC, como a API as devolve: para mostrar no horário do aparelho, use o `toLocal()`.
@immutable
final class UserSession {
  const new({
    required this.id,
    required this.createdAt,
    required this.expiresAt,
    required this.current,
    this.ipAddress,
    this.userAgent,
  });

  /// O id que o `DELETE /api/users/me/sessions/:id` recebe.
  final String id;

  /// A data e a hora do login.
  final DateTime createdAt;

  final DateTime expiresAt;

  /// O IP do login. `null` nas sessões abertas antes de a API gravá-lo. Não vai para log.
  final String? ipAddress;

  /// O `User-Agent` do login, como chegou na API. `null` como o [ipAddress]. Não vai para log.
  final String? userAgent;

  /// Se é a sessão deste aparelho, a que fez a listagem: ela não tem o "Encerrar".
  final bool current;

  /// O aparelho da sessão, lido do [userAgent], para a lista mostrar ([deviceOf]).
  SessionDevice get device => deviceOf(userAgent);

  @override
  bool operator ==(Object other) =>
      other is UserSession &&
      other.id == id &&
      other.createdAt == createdAt &&
      other.expiresAt == expiresAt &&
      other.ipAddress == ipAddress &&
      other.userAgent == userAgent &&
      other.current == current;

  @override
  int get hashCode => Object.hash(id, createdAt, expiresAt, ipAddress, userAgent, current);

  @override
  String toString() =>
      // O IP e o user agent dizem de onde a conta entrou: não vão para log.
      'UserSession(id: $id, createdAt: $createdAt, expiresAt: $expiresAt, '
      'ipAddress: ${ipAddress == null ? null : '***'}, '
      'userAgent: ${userAgent == null ? null : '***'}, current: $current)';
}

/// O tipo de aparelho de uma sessão, lido do user agent.
enum SessionDeviceKind {
  /// O app do ReportaAi, com o `User-Agent` que ele manda desde a sprint 4.
  app,

  /// Um navegador, como o do painel web.
  browser,

  /// Sem user agent, ou com um que o app não reconhece (como o do `api.http` e o das versões do
  /// app de antes do `User-Agent` próprio).
  unknown,
}

/// O aparelho de uma sessão: o [kind] e o [label] que a lista mostra.
@immutable
final class SessionDevice {
  const new(this.kind, this.label);

  final SessionDeviceKind kind;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is SessionDevice && other.kind == kind && other.label == label;

  @override
  int get hashCode => Object.hash(kind, label);

  @override
  String toString() => 'SessionDevice(${kind.name}, $label)';
}

/// O `User-Agent` do app (o `buildUserAgent` do `core/network`): `ReportaAiCm/0.1.0 (Android)`,
/// com o sistema entre os parênteses.
final _appUserAgent = RegExp(r'^ReportaAiCm/\S+(?: \(([^()]+)\))?');

/// O aparelho do [userAgent] de uma sessão: "App ReportaAi (Android)" para o app, "Navegador"
/// para os navegadores e "Aparelho desconhecido" para o resto, inclusive sem o user agent.
SessionDevice deviceOf(String? userAgent) {
  final value = userAgent?.trim() ?? '';

  if (_appUserAgent.firstMatch(value) case final match?) {
    final system = match.group(1)?.trim();
    return SessionDevice(
      SessionDeviceKind.app,
      system == null || system.isEmpty ? 'App ReportaAi' : 'App ReportaAi ($system)',
    );
  }

  // Todos os navegadores atuais começam o user agent com o "Mozilla/5.0".
  if (value.startsWith('Mozilla/')) {
    return const SessionDevice(SessionDeviceKind.browser, 'Navegador');
  }

  return const SessionDevice(SessionDeviceKind.unknown, 'Aparelho desconhecido');
}
