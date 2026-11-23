import 'package:reportaai_cm/features/reports/domain/models/report_limits.dart';

/// A mensagem da descrição longa, a mesma da API.
const descriptionTooLongMessage =
    'A descrição deve ter no máximo ${ReportLimits.descriptionMaxLength} caracteres.';

/// A descrição como a API guarda (o `ReportDescription` do backend): sem os espaços das pontas, e
/// `null` quando fica vazia.
String? normalizeReportDescription(String text) {
  final value = text.trim();
  return value.isEmpty ? null : value;
}

/// Se a descrição cabe nos 500 caracteres (RN27), contados como a API conta: depois do `trim`, e
/// cada caractere (mesmo um emoji) vale um.
bool isValidReportDescription(String text) =>
    text.trim().runes.length <= ReportLimits.descriptionMaxLength;
