/// O DDD, o começo do número (4 dígitos no fixo e 5 no celular) e os 4 dígitos do fim.
final _phoneParts = RegExp(r'^(\d{2})(\d{4,5})(\d{4})$');

/// O telefone com o DDD entre parênteses: `(44) 99999-8888` no celular (11 dígitos) e
/// `(44) 3333-4444` no fixo (10 dígitos). Recebe só os dígitos, como a API os devolve. Fora
/// desses formatos, devolve o telefone como veio.
String formatPhone(String phone) => switch (_phoneParts.firstMatch(phone)) {
  final match? => '(${match[1]}) ${match[2]}-${match[3]}',
  null => phone,
};
