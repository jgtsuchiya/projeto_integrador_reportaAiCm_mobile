import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/widgets/primary_button.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';

/// Tela (ou área) de erro: o título, a mensagem e o "Tentar de novo", quando há [onRetry].
///
/// A [message] costuma vir de `ApiException.messageOf(error)`, já em português.
class ErrorView extends StatelessWidget {
  const new({required this.message, this.title = 'Algo deu errado', this.onRetry, super.key});

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ScrollableCenter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          // O leitor de tela anuncia o erro assim que ele aparece.
          Semantics(
            liveRegion: true,
            child: Column(
              children: [
                Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(message, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
              ],
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            PrimaryButton(label: 'Tentar de novo', onPressed: onRetry),
          ],
        ],
      ),
    );
  }
}
