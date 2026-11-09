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

    TextButton button(WidgetTester tester) => tester.widget(find.byType(TextButton));

    testWidgets('deve encerrar a sessão pelo AuthController', (tester) async {
      await pumpButton(tester);

      await tester.tap(find.text('Sair'));
      await tester.pump();

      expect(fakes.session.signOutCalls, 1);
      expect(tester.container().read(authControllerProvider), const AuthUnauthenticated());
    });

    testWidgets('deve ficar desativado enquanto a saída não termina', (tester) async {
      final pending = fakes.session.signOutPending = Completer<void>();
      await pumpButton(tester);

      await tester.tap(find.text('Sair'));
      await tester.pump();
      await tester.tap(find.text('Sair'), warnIfMissed: false);

      expect(button(tester).onPressed, isNull);
      expect(fakes.session.signOutCalls, 1);

      pending.complete();
      await tester.pump();

      expect(button(tester).onPressed, isNotNull);
    });

    testWidgets('deve avisar e continuar logado sem conexão (RM10)', (tester) async {
      fakes.session.signOutError = const NetworkException();
      await pumpButton(tester);

      await tester.tap(find.text('Sair'));
      await tester.pump();

      expect(find.widgetWithText(SnackBar, NetworkException.defaultMessage), findsOneWidget);
      expect(tester.container().read(authControllerProvider), AuthAuthenticated(clientProfile));
      expect(button(tester).onPressed, isNotNull, reason: 'O usuário pode tentar sair de novo.');
    });
  });
}
