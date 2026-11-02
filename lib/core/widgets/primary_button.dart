import 'package:material_ui/material_ui.dart';

/// Botão da ação principal da tela. Com [isLoading], mostra o indicador e ignora o toque, para a
/// ação não rodar duas vezes (ex.: o "Entrar" do login).
class PrimaryButton extends StatelessWidget {
  const new({required this.label, required this.onPressed, this.isLoading = false, super.key});

  final String label;

  /// `null` desativa o botão.
  final VoidCallback? onPressed;

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (!isLoading) {
      return FilledButton(onPressed: onPressed, child: Text(label));
    }

    final colorScheme = Theme.of(context).colorScheme;

    // Carregando, o botão fica sem ação, mas com a cor de ativo: não é um botão desativado.
    return FilledButton(
      onPressed: null,
      style: FilledButton.styleFrom(
        disabledBackgroundColor: colorScheme.primary,
        disabledForegroundColor: colorScheme.onPrimary,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.onPrimary,
              semanticsLabel: 'Carregando',
            ),
          ),
          const SizedBox(width: 12),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}
