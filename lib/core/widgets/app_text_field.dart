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
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.enabled = true,
    this.autofillHints,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.suffixIcon,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? errorText;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool autocorrect;

  /// As sugestões e o aprendizado do teclado. Desligue no campo de senha que pode ficar visível,
  /// para o teclado não sugerir nem aprender a senha.
  final bool enableSuggestions;

  final bool enabled;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      // Num campo oculto (senha), nem correção nem sugestão do teclado.
      autocorrect: autocorrect && !obscureText,
      enableSuggestions: enableSuggestions && !obscureText,
      enableIMEPersonalizedLearning: enableSuggestions && !obscureText,
      enabled: enabled,
      autofillHints: autofillHints,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        errorText: errorText,
        // Com a fonte grande, a mensagem quebra em linhas em vez de ser cortada.
        errorMaxLines: 3,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
