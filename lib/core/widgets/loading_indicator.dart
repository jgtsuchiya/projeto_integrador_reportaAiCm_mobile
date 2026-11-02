import 'package:material_ui/material_ui.dart';

/// Indicador de carregamento centralizado, com uma mensagem opcional embaixo.
class LoadingIndicator extends StatelessWidget {
  const new({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Com a mensagem, o leitor de tela lê só ela, sem repetir o "Carregando".
            CircularProgressIndicator(semanticsLabel: message == null ? 'Carregando' : null),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
