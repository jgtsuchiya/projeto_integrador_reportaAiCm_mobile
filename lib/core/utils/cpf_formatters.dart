final _cpfDigits = RegExp(r'^\d{11}$');

/// O CPF mascarado, como no painel (RN12): `***.982.247-**`, só com os seis dígitos do meio.
/// Recebe o CPF só com dígitos, como a API o devolve. Fora desse formato, mascara todos os
/// dígitos: o CPF completo nunca aparece na tela (RM09).
String maskCpf(String cpf) => _cpfDigits.hasMatch(cpf)
    ? '***.${cpf.substring(3, 6)}.${cpf.substring(6, 9)}-**'
    : '***.***.***-**';
