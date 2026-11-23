/// O status do reporte. O [apiName] é o código da API.
enum ReportStatus {
  /// Em validação: espera as confirmações dos outros cidadãos.
  pending('PENDING'),

  /// Confirmado por outros cidadãos: o reporte passa a ser considerado verdadeiro.
  confirmed('CONFIRMED'),

  /// Descartado: outros cidadãos não encontraram o buraco.
  rejected('REJECTED'),

  /// Um status que o app ainda não conhece, como os do atendimento que o painel da prefeitura vai
  /// criar. O app mostra "Em acompanhamento", sem quebrar.
  unknown(null);

  new(this.apiName);

  /// O código da API. `null` no [unknown], que não é um filtro.
  final String? apiName;

  /// O status do [apiName], ou o [unknown] para um código que o app não conhece.
  static ReportStatus fromApiName(String apiName) {
    for (final status in values) {
      if (status.apiName == apiName) return status;
    }
    return unknown;
  }
}
