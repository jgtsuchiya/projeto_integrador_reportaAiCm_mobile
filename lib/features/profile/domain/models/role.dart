/// O papel do usuário (RN01). O app é só do [client] (RM01): o ADM e o SuperAdm usam o painel web.
enum Role {
  client,
  admin,
  superAdmin,

  /// Um papel que a API passou a ter e o app ainda não conhece. Não entra no app, como o ADM.
  unknown,
}
