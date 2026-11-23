import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Campo de texto do app, com o rótulo e a mensagem de erro embaixo.
///
/// O erro vem da validação local ([validator], conferida pelo `Form`) ou de fora, pelo
/// [errorText], como o erro do campo que veio da API. A validação local tem prioridade.
class AppTextField extends StatelessWidget {
  const new({
    required this.label,
    this.controller,
    this.errorText,
    this.hintText,
    this.helperText,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.enabled = true,
    this.autofillHints,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.suffixIcon,
    this.scrollPadding = const EdgeInsets.all(20),
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? errorText;
  final String? hintText;

  /// O texto de ajuda embaixo do campo, como o formato esperado. Some quando há um erro.
  final String? helperText;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final bool autocorrect;

  /// As sugestões e o aprendizado do teclado. Desligue no campo de senha que pode ficar visível,
  /// para o teclado não sugerir nem aprender a senha.
  final bool enableSuggestions;

  final bool enabled;
  final Iterable<String>? autofillHints;

  /// As máscaras do campo, como o `CpfInputFormatter` de `core/utils/`.
  final List<TextInputFormatter>? inputFormatters;

  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffixIcon;

  /// O espaço que a tela deixa em volta do campo quando rola até ele, com o teclado aberto. No
  /// último campo de um formulário, um espaço maior embaixo deixa o botão de enviar à vista.
  final EdgeInsets scrollPadding;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      // Num campo oculto (senha), nem correção nem sugestão do teclado.
      autocorrect: autocorrect && !obscureText,
      enableSuggestions: enableSuggestions && !obscureText,
      enableIMEPersonalizedLearning: enableSuggestions && !obscureText,
      enabled: enabled,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      scrollPadding: scrollPadding,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        // Com a fonte grande, a ajuda e a mensagem quebram em linhas em vez de serem cortadas.
        helperMaxLines: 3,
        errorText: errorText,
        errorMaxLines: 3,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
