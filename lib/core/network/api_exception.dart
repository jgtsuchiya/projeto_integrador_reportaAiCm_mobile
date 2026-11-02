import 'package:meta/meta.dart';

/// Erro de uma chamada à API, já convertido para o app. Os repositórios só lançam estas exceções
/// (ver o `callApi`), e a tela mostra a [message], que sai sempre em português.
///
/// A `message` vem da API quando a resposta está no formato de erro da aplicação
/// (`statusCode`, `error`, `message`, `details`). Sem ela, como sem conexão ou nas respostas do
/// SuperTokens, que vêm em inglês, vale o texto padrão de cada exceção.
sealed class ApiException implements Exception {
  const new(this.message);

  final String message;

  /// A mensagem para a tela de qualquer erro: a da [ApiException] ou, para outro erro, a padrão.
  static String messageOf(Object error) =>
      error is ApiException ? error.message : ServerException.defaultMessage;

  @override
  // O texto só aparece em log de debug. Com o --obfuscate, o nome do tipo sai trocado, e tudo bem.
  // ignore: no_runtimetype_tostring
  String toString() => '$runtimeType: $message';
}

/// Erro de um campo, no `details` do 400.
@immutable
final class FieldError {
  const new({required this.field, required this.message});

  final String field;
  final String message;

  @override
  bool operator ==(Object other) =>
      other is FieldError && other.field == field && other.message == message;

  @override
  int get hashCode => Object.hash(field, message);

  @override
  String toString() => 'FieldError($field: $message)';
}

/// 400: campos inválidos ou ausentes.
final class ValidationException extends ApiException {
  const new({String? message, this.fieldErrors = const []}) : super(message ?? defaultMessage);

  static const defaultMessage = 'Dados inválidos. Confira os campos.';

  final List<FieldError> fieldErrors;

  /// A mensagem do campo, para mostrar embaixo dele.
  String? messageFor(String field) {
    for (final error in fieldErrors) {
      if (error.field == field) return error.message;
    }
    return null;
  }
}

/// 401: sem sessão, sessão expirada ou senha de confirmação incorreta (com o [field]).
final class UnauthorizedException extends ApiException {
  const new({String? message, this.field}) : super(message ?? defaultMessage);

  static const defaultMessage = 'Sua sessão expirou. Entre de novo.';

  final String? field;
}

/// 403 de permissão: o papel do usuário não pode fazer a operação.
final class ForbiddenException extends ApiException {
  const new({String? message}) : super(message ?? defaultMessage);

  static const defaultMessage = 'Você não tem permissão para fazer isso.';
}

/// 403 da sessão pendente: o login passou pela senha e falta o código da verificação em duas
/// etapas. A API responde no formato do SuperTokens (`claimValidationErrors`, sem `statusCode`).
final class SecondFactorPendingException extends ApiException {
  const new() : super(defaultMessage);

  static const defaultMessage = 'Falta confirmar o código da verificação em duas etapas.';
}

/// 404: o recurso não existe.
final class NotFoundException extends ApiException {
  const new({String? message}) : super(message ?? defaultMessage);

  static const defaultMessage = 'Não encontramos o que você procurou.';
}

/// 409: o dado já existe, como o e-mail ou o CPF já cadastrados (com o [field]).
final class ConflictException extends ApiException {
  const new({String? message, this.field}) : super(message ?? defaultMessage);

  static const defaultMessage = 'Esses dados já estão cadastrados.';

  final String? field;
}

/// 422: a operação quebra uma regra de negócio.
final class BusinessRuleException extends ApiException {
  const new({String? message}) : super(message ?? defaultMessage);

  static const defaultMessage = 'Não foi possível concluir a operação.';
}

/// 429: muitas requisições do mesmo IP. O [retryAfter] vem do header `Retry-After` (segundos).
final class RateLimitException extends ApiException {
  const new({String? message, this.retryAfter}) : super(message ?? defaultMessage);

  static const defaultMessage = 'Muitas tentativas. Tente de novo em instantes.';

  final Duration? retryAfter;
}

/// 5xx, outro status sem tratamento próprio ou resposta fora do formato esperado. A mensagem é
/// sempre a padrão: o detalhe do erro fica no [cause], para o log.
final class ServerException extends ApiException {
  const new({this.statusCode, this.cause}) : super(defaultMessage);

  static const defaultMessage = 'Algo deu errado. Tente de novo em instantes.';

  final int? statusCode;
  final Object? cause;
}

/// Sem conexão com a API ou sem resposta dentro do tempo limite.
final class NetworkException extends ApiException {
  const new({this.isTimeout = false}) : super(defaultMessage);

  static const defaultMessage = 'Não foi possível conectar ao servidor. Confira a sua internet.';

  final bool isTimeout;
}
