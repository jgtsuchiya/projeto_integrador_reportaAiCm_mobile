import 'dart:math';

/// Um UUID versão 4 (RFC 9562), aleatório, como `3b241101-e2bb-4255-8caf-4136c566a962`. Usa o
/// [Random.secure] do sistema, se o [random] não for passado (os testes passam um com a semente).
///
/// É a `Idempotency-Key` do envio do reporte (RM24): a chave não pode se repetir entre os
/// reportes, então não vale um gerador previsível.
String randomUuidV4([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = [for (var i = 0; i < 16; i++) source.nextInt(256)];

  // A versão (4) no começo do 7º byte e a variante (10xx) no começo do 9º.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hex = [for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0')].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
