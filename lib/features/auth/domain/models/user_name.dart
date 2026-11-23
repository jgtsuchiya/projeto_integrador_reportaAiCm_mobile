// O tamanho do nome é o mesmo da entidade `User` do backend (`USER_NAME_MAX_LENGTH`).
const userNameMaxLength = 120;

/// Se o [name] tem o tamanho que a API aceita: de 1 a 120 caracteres, sem os espaços das pontas.
bool isValidUserName(String name) {
  final value = name.trim();

  return value.isNotEmpty && value.length <= userNameMaxLength;
}
