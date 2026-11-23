import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/widgets/app_text_field.dart';

/// Campo de senha das telas da conta, com o botão de mostrar e ocultar. Também com a senha
/// visível, o teclado não corrige nem aprende a senha.
class PasswordField extends StatefulWidget {
  const new({
    required this.label,
    required this.controller,
    required this.autofillHints,
    this.errorText,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.onFieldSubmitted,
    super.key,
  });

  final String label;
  final TextEditingController controller;

  /// O `AutofillHints.password` para a senha atual e o `newPassword` para a nova, para o
  /// gerenciador de senhas preencher a atual e oferecer guardar a nova.
  final Iterable<String> autofillHints;

  final String? errorText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      controller: widget.controller,
      errorText: widget.errorText,
      textInputAction: widget.textInputAction,
      obscureText: !_isVisible,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      suffixIcon: IconButton(
        onPressed: () => setState(() => _isVisible = !_isVisible),
        tooltip: _isVisible ? 'Ocultar senha' : 'Mostrar senha',
        icon: Icon(_isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
      ),
    );
  }
}
