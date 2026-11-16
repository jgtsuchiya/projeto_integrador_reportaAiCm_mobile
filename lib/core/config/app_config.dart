import 'package:meta/meta.dart';

/// Configuração do app, lida no build pelo `--dart-define-from-file` (ex.: `env/dev.json`).
///
/// O construtor valida e normaliza os valores, como o schema de ambiente da API: com um valor
/// ausente ou inválido, ele lança uma [AppConfigException] que diz o que está errado.
@immutable
final class AppConfig {
  factory({required String apiUrl}) => AppConfig._(apiUrl: _parseApiUrl(apiUrl));

  /// Lê as variáveis passadas no build. Sem o `--dart-define-from-file`, elas chegam vazias.
  factory fromEnvironment() => AppConfig(apiUrl: const String.fromEnvironment(apiUrlKey));

  const new _({required this.apiUrl});

  static const apiUrlKey = 'API_URL';

  /// Endereço da API, sem o `/api` e sem a barra do final (ex.: `http://10.0.2.2:3000`). É também
  /// o `apiDomain` do SDK do SuperTokens.
  final String apiUrl;

  /// Base das rotas da aplicação, que ficam sob o prefixo `/api`.
  String get apiBaseUrl => '$apiUrl/api';

  @override
  bool operator ==(Object other) => other is AppConfig && other.apiUrl == apiUrl;

  @override
  int get hashCode => apiUrl.hashCode;

  @override
  String toString() => 'AppConfig(apiUrl: $apiUrl)';
}

/// A configuração do build está ausente ou inválida. A [message] diz o que corrigir.
final class AppConfigException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => 'AppConfigException: $message';
}

const _example = 'http://10.0.2.2:3000';

String _parseApiUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    throw const AppConfigException(
      'A variável ${AppConfig.apiUrlKey} não foi definida. Copie o env/dev.example.json para '
      'env/dev.json e rode o app com --dart-define-from-file=env/dev.json.',
    );
  }

  final uri = Uri.tryParse(value);
  final isHttp = uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  if (!isHttp || uri.host.isEmpty || uri.hasQuery || uri.hasFragment) {
    throw AppConfigException(
      'A ${AppConfig.apiUrlKey} "$value" não é um endereço válido. Use o formato '
      'http://<endereço>:<porta>, por exemplo $_example.',
    );
  }

  final apiUrl = value.replaceFirst(RegExp(r'/+$'), '');
  // O erro mais comum: o SDK do SuperTokens e o Dio acrescentam o /api por conta própria.
  if (Uri.parse(apiUrl).path.toLowerCase().endsWith('/api')) {
    final withoutApi = apiUrl.substring(0, apiUrl.length - '/api'.length);
    throw AppConfigException(
      'A ${AppConfig.apiUrlKey} deve ser o endereço da API sem o /api: use "$withoutApi" em vez '
      'de "$value".',
    );
  }

  return apiUrl;
}
