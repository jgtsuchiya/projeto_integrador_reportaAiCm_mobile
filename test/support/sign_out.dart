import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// O "Sair" do diálogo de confirmação (RM10), que não se confunde com o botão que abre o diálogo.
final Finder confirmSignOutButton = find.descendant(
  of: find.byType(AlertDialog),
  matching: find.text('Sair'),
);

extension SignOut on WidgetTester {
  /// Toca no "Sair" da tela e confirma no diálogo, como o usuário (RM10). Termina com a saída
  /// começada: o teste decide quanto esperar por ela.
  Future<void> signOutAndConfirm() async {
    await tap(find.text('Sair'));
    await pumpAndSettle();
    await tap(confirmSignOutButton);
    await pump();
  }
}
