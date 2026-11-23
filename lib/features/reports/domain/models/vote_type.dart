/// O voto da validação dos reportes (RN37): o buraco "está lá" ou "não está lá". O [apiName] é o
/// código da API.
enum VoteType {
  /// "Está lá": conta como confirmação. Com 10, o reporte é confirmado (RN39).
  confirm('CONFIRM'),

  /// "Não está lá": com 10, o reporte é descartado (RN39).
  deny('DENY');

  new(this.apiName);

  final String apiName;

  /// O voto do [apiName], ou `null` para um código que o app não conhece.
  static VoteType? fromApiName(String apiName) {
    for (final vote in values) {
      if (vote.apiName == apiName) return vote;
    }
    return null;
  }
}
