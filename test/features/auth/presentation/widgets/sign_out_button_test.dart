import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/widgets/sign_out_button.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';
import '../../../../support/pump_app.dart';
import '../../../../support/sign_out.dart';

void main() {
  group('SignOutButton', () {
    late AuthFakes fakes;

    setUp(() => fakes = AuthFakes(signedIn: true));

    /// Monta o botão com o Client já dentro.
    Future<void> pumpButton(WidgetTester tester) async {
      await tester.pumpApp(
        const Scaffold(body: Center(child: SignOutButton())),
        overrides: fakes.overrides,
      );
      tester.container().read(authControllerProvider);
      await tester.pump();
      expect(tester.container().read(authControllerProvider), AuthAuthenticated(clientProfile));
    }

    TextButton button(WidgetTester tester) =>
        tester.widget(find.widgetWithText(TextButton, 'Sair').first);

    testWidgets('deve pedir confirmação antes de sair (RM10)', (tester) async {
      await pumpButton(tester);

      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Sair da conta?'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(fakes.session.signOutCalls, 0);
    });

    testWidgets('deve continuar logado no "Cancelar"', (tester) async {
      await pumpButton(tester);
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(fakes.session.signOutCalls, 0);
      expect(tester.container().read(authControllerProvider), AuthAuthenticated(clientProfile));
    });

    testWidgets('deve continuar logado ao fechar o diálogo com um toque fora dele', (tester) async {
      await pumpButton(tester);
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(fakes.session.signOutCalls, 0);
    });

    testWidgets('deve encerrar a sessão pelo AuthController depois da confirmação', (tester) async {
      await pumpButton(tester);

      await tester.signOutAndConfirm();
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(fakes.session.signOutCalls, 1);
      expect(tester.container().read(authControllerProvider), const AuthUnauthenticated());
    });

    testWidgets('deve ficar desativado enquanto a saída não termina', (tester) async {
      final pending = fakes.session.signOutPending = Completer<void>();
      await pumpButton(tester);

      await tester.signOutAndConfirm();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair'), warnIfMissed: false);
      await tester.pump();

      expect(button(tester).onPressed, isNull);
      expect(
        find.byType(AlertDialog),
        findsNothing,
        reason: 'O botão desativado não abre o diálogo.',
      );
      expect(fakes.session.signOutCalls, 1);

      pending.complete();
      await tester.pumpAndSettle();

      expect(button(tester).onPressed, isNotNull);
    });

    testWidgets('deve avisar e continuar logado sem conexão (RM10)', (tester) async {
      fakes.session.signOutError = const NetworkException();
      await pumpButton(tester);

      await tester.signOutAndConfirm();

      expect(find.widgetWithText(SnackBar, NetworkException.defaultMessage), findsOneWidget);
      expect(tester.container().read(authControllerProvider), AuthAuthenticated(clientProfile));
      expect(button(tester).onPressed, isNotNull, reason: 'O usuário pode tentar sair de novo.');
    });
  });
}
