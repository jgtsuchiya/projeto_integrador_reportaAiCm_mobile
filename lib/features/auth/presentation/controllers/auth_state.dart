import 'package:meta/meta.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_profile.dart';

/// Por que o usuário voltou ao login sem ter pedido para sair. A tela de login mostra a [message].
enum UnauthenticatedReason {
  /// A sessão acabou fora do app: refresh token vencido, usuário inativado, sessão encerrada em
  /// outro aparelho ou senha trocada (RM07).
  sessionExpired('Sua sessão expirou. Entre de novo.'),

  /// O papel não é o CLIENT: o ADM e o SuperAdm usam o painel web (RM01).
  roleNotAllowed('Este aplicativo é para cidadãos. Administradores usam o painel web.'),

  /// A sessão está pendente da segunda etapa do login, e a tela do código ainda não existe (RM08).
  secondFactorPending('A verificação em duas etapas ainda não está disponível no app.');

  new(this.message);

  final String message;
}

/// O estado de login do app, guardado pelo `AuthController`. O redirect das rotas escolhe a tela a
/// partir dele: nenhuma tela navega sozinha depois do login ou do "Sair".
@immutable
sealed class AuthState {
  const new();
}

/// O app está conferindo a sessão guardada, na abertura ou no "Tentar de novo". Fica na tela de
/// abertura.
final class AuthChecking extends AuthState {
  const new();

  @override
  bool operator ==(Object other) => other is AuthChecking;

  @override
  int get hashCode => (AuthChecking).hashCode;

  @override
  String toString() => 'AuthChecking()';
}

/// Sem sessão: fica no login. O [reason] diz por que o usuário voltou ao login, e é `null` quando
/// ele nunca entrou ou saiu pelo "Sair".
final class AuthUnauthenticated extends AuthState {
  const new({this.reason});

  final UnauthenticatedReason? reason;

  @override
  bool operator ==(Object other) => other is AuthUnauthenticated && other.reason == reason;

  @override
  int get hashCode => Object.hash(AuthUnauthenticated, reason);

  @override
  String toString() => 'AuthUnauthenticated(reason: ${reason?.name})';
}

/// O Client entrou: a sessão está aberta, e o [profile] veio do `GET /api/users/me`.
final class AuthAuthenticated extends AuthState {
  const new(this.profile);

  final UserProfile profile;

  @override
  bool operator ==(Object other) => other is AuthAuthenticated && other.profile == profile;

  @override
  int get hashCode => profile.hashCode;

  @override
  String toString() => 'AuthAuthenticated($profile)';
}

/// Há uma sessão guardada, mas o perfil não carregou, como sem rede na abertura (RM06). A sessão
/// não é apagada: a tela de abertura mostra o [error] com o "Tentar de novo" e o "Sair".
final class AuthLoadFailed extends AuthState {
  const new(this.error);

  /// Em geral, uma `ApiException`, como a `NetworkException`. A tela mostra a mensagem dele pelo
  /// `ApiException.messageOf`.
  final Object error;

  @override
  bool operator ==(Object other) => other is AuthLoadFailed && other.error == error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'AuthLoadFailed($error)';
}
