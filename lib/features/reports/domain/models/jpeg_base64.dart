import 'dart:convert';
import 'dart:typed_data';

import 'package:reportaai_cm/features/reports/domain/models/jpeg.dart';

/// O JPEG em base64 para o JSON da API: o padrão (RFC 4648), com o `=` do fim, sem quebra de
/// linha e sem o prefixo `data:image/jpeg;base64,`. Lança o [ArgumentError] quando os bytes não
/// têm a assinatura do JPEG: é um defeito do app, que só envia a foto já tratada.
String encodeJpegBase64(Uint8List bytes) {
  if (!hasJpegSignature(bytes)) {
    throw ArgumentError('Os bytes não são de uma imagem JPEG.', 'bytes');
  }
  return base64Encode(bytes);
}

/// Os bytes do JPEG em base64 que a API devolve. O decode é estrito, como o da API: só o
/// alfabeto padrão, com o `=` do fim e sem quebra de linha. Lança a [FormatException] quando o
/// texto não é base64 ou não é de um JPEG (a assinatura `FF D8 FF`). A mensagem não traz o texto,
/// que é uma foto (RM27).
Uint8List decodeJpegBase64(String text) {
  if (text.length % 4 != 0 || !_base64Pattern.hasMatch(text)) {
    throw const FormatException('O texto da imagem não está em base64.');
  }

  final Uint8List bytes;
  try {
    bytes = base64Decode(text);
  } on FormatException {
    throw const FormatException('O texto da imagem não está em base64.');
  }

  if (!hasJpegSignature(bytes)) {
    throw const FormatException('A imagem não é um JPEG.');
  }
  return bytes;
}

/// Só o alfabeto padrão, com o `=` apenas no fim.
final _base64Pattern = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');
