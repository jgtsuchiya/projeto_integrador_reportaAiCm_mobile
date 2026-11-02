import 'package:material_ui/material_ui.dart';

/// Centraliza o conteúdo quando ele cabe na área e o deixa rolar quando não cabe, como com a
/// fonte do sistema em 200%. Dentro de algo que já rola, mostra só o conteúdo, sem outra rolagem.
class ScrollableCenter extends StatelessWidget {
  const new({required this.child, this.padding = const EdgeInsets.all(24), super.key});

  /// Largura máxima do conteúdo, para as telas não esticarem no tablet e na horizontal.
  static const maxContentWidth = 600.0;

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          child: Padding(padding: padding, child: child),
        );

        if (!constraints.hasBoundedHeight) return Center(child: content);

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}
