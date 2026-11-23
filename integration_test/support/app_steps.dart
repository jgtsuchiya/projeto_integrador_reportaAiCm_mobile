import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'pump_until.dart';

final Finder loginTitle = find.text('Entrar no ReportaAi Cm');

/// Os passos que o usuário faz no app, para os testes de integração. Com o teclado aberto, o botão
/// pode ficar fora da tela: cada toque rola a tela até ele antes.
extension AppSteps on WidgetTester {
  /// Toca no [target], rolando a tela até ele, e desenha o quadro seguinte.
  Future<void> tapVisible(Finder target) async {
    await ensureVisible(target);
    await pumpAndSettle();
    await tap(target);
    await pump();
  }

  /// Digita o [text] no campo [field], como o usuário: toca nele e espera o foco antes. Sem o
  /// toque, o campo que perdeu o foco para outro controle (como a caixa de confirmação da
  /// exclusão) não recebe o texto no desktop.
  Future<void> typeInto(Finder field, String text) async {
    await ensureVisible(field);
    await tap(field);
    await pumpAndSettle();
    await enterText(field, text);
    await pumpAndSettle();
  }

  /// Preenche o login e toca no "Entrar". Termina com o login enviado: o teste espera a tela
  /// seguinte.
  Future<void> signInWith({required String email, required String password}) async {
    await enterText(find.widgetWithText(TextFormField, 'E-mail'), email);
    await enterText(find.widgetWithText(TextFormField, 'Senha'), password);
    await tapVisible(find.text('Entrar'));
  }

  /// Da tela inicial, abre a "Minha conta" e a entrada com o [entry].
  Future<void> openAccountEntry(String entry) async {
    await tapVisible(find.byTooltip('Minha conta'));
    await pumpUntilFound(find.text(entry), reason: 'A "Minha conta" não abriu.');
    await tapVisible(find.text(entry));
    await pumpAndSettle();
  }

  /// Toca no "Sair" e confirma, e espera o login.
  Future<void> signOutToLogin() async {
    await tapVisible(find.text('Sair'));
    await pumpAndSettle();
    await tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Sair')));
    await pumpUntilFound(loginTitle, reason: 'O "Sair" não voltou ao login.');
    await pumpAndSettle();
  }

  /// Fecha o aviso de baixo da tela (o `SnackBar`), como o usuário que o arrasta para o lado,
  /// para ele não cobrir os botões. Esperar o tempo dele não basta no desktop.
  Future<void> dismissSnackBars() async {
    state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars();
    await pumpAndSettle();
  }
}
