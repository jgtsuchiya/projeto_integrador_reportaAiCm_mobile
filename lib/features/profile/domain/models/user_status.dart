/// O status de acesso da conta. Quem está logado está sempre [active]: a API recusa o login de
/// quem não está e encerra a sessão de quem é inativado.
enum UserStatus {
  /// Só do ADM convidado que ainda não aceitou o convite.
  pending,
  active,
  inactive,

  /// Um status que a API passou a ter e o app ainda não conhece.
  unknown,
}
