import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/confirmation_password.dart';
import 'package:reportaai_cm/features/account/presentation/views/delete_account_view.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';
import '../../../../support/pump_app.dart';

const _password = 'senha-forte-1';

final Finder _passwordField = find.widgetWithText(TextFormField, 'Senha atual');
final Finder _confirmation = find.byType(CheckboxListTile);
final Finder _delete = find.widgetWithText(FilledButton, 'Excluir minha conta');

void main() {
  group('DeleteAccountView', () {
    late AuthFakes fakes;

    setUp(() => fakes = AuthFakes(signedIn: true));

    Future<void> pumpView(WidgetTester tester) async {
      await tester.pumpApp(const DeleteAccountView(), overrides: fakes.overrides);
      tester.container().read(authControllerProvider);
      await tester.pumpAndSettle();
    }

    FilledButton deleteButton(WidgetTester tester) => tester.widget<FilledButton>(_delete);

    Future<void> fillIn(WidgetTester tester, {String password = _password}) async {
      await tester.enterText(_passwordField, password);
      await tester.ensureVisible(_confirmation);
      await tester.tap(_confirmation);
      await tester.pump();
    }

    Future<void> delete(WidgetTester tester) async {
      await tester.ensureVisible(_delete);
      await tester.tap(_delete);
      await tester.pumpAndSettle();
    }

    AuthState auth(WidgetTester tester) => tester.container().read(authControllerProvider);

    testWidgets('deve explicar o que acontece antes da senha (RM17)', (tester) async {
      await pumpView(tester);

      expect(find.text('A exclusão não pode ser desfeita'), findsOneWidget);
      for (final item in DeleteAccountView.consequences) {
        expect(find.text(item), findsOneWidget);
      }
      expect(
        tester.getTopLeft(find.text(DeleteAccountView.consequences.last)).dy,
        lessThan(tester.getTopLeft(_passwordField).dy),
      );
    });

    testWidgets('deve ativar o botão só com a senha e a confirmação', (tester) async {
      await pumpView(tester);
      expect(deleteButton(tester).onPressed, isNull);

      await tester.enterText(_passwordField, _password);
      // O botão acompanha a senha: o quadro depois da última letra o ativa.
      await tester.pump();
      expect(deleteButton(tester).onPressed, isNull);

      await tester.tap(_confirmation);
      await tester.pump();
      expect(deleteButton(tester).onPressed, isNotNull);

      await tester.enterText(_passwordField, '');
      await tester.pump();
      expect(deleteButton(tester).onPressed, isNull);
    });

    testWidgets('deve usar a cor de erro no botão', (tester) async {
      await pumpView(tester);
      await fillIn(tester);

      final context = tester.element(_delete);
      final color = deleteButton(tester).style?.backgroundColor?.resolve({});

      expect(color, Theme.of(context).colorScheme.error);
    });

    testWidgets('deve excluir a conta e voltar ao login com o aviso (204)', (tester) async {
      await pumpView(tester);

      await fillIn(tester);
      await delete(tester);

      expect(fakes.profile.deleteAccountCalls, [_password]);
      expect(auth(tester), const AuthUnauthenticated(reason: UnauthenticatedReason.accountDeleted));
      expect(fakes.session.hasStoredSession, isFalse);
    });

    testWidgets('deve mostrar a senha incorreta no campo e apagá-lo (422, RM15)', (tester) async {
      fakes.profile.deleteAccountError = const BusinessRuleException(
        message: 'Senha incorreta.',
        field: 'password',
      );
      await pumpView(tester);

      await fillIn(tester, password: 'errada-1');
      await delete(tester);

      expect(find.text(ConfirmationPasswordMessages.incorrect), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: _passwordField, matching: find.byType(EditableText)),
            )
            .controller
            .text,
        isEmpty,
      );
      expect(auth(tester), AuthAuthenticated(clientProfile));
    });

    testWidgets('deve excluir com a senha certa depois da errada', (tester) async {
      fakes.profile.deleteAccountError = const BusinessRuleException(
        message: 'Senha incorreta.',
        field: 'password',
      );
      await pumpView(tester);
      await fillIn(tester, password: 'errada-1');
      await delete(tester);
      fakes.profile.deleteAccountError = null;

      await tester.enterText(_passwordField, _password);
      // O botão acompanha a senha: o quadro depois da última letra o ativa.
      await tester.pump();
      await delete(tester);

      expect(fakes.profile.deleteAccountCalls, ['errada-1', _password]);
      expect(auth(tester), const AuthUnauthenticated(reason: UnauthenticatedReason.accountDeleted));
    });

    testWidgets('deve mostrar o erro sem conexão e manter a conta', (tester) async {
      fakes.profile.deleteAccountError = const NetworkException();
      await pumpView(tester);

      await fillIn(tester);
      await delete(tester);

      expect(find.text(NetworkException.defaultMessage), findsOneWidget);
      expect(auth(tester), AuthAuthenticated(clientProfile));
    });

    testWidgets('deve mostrar o carregando durante a exclusão', (tester) async {
      final pending = fakes.profile.deleteAccountPending = Completer<void>();
      await pumpView(tester);

      await fillIn(tester);
      await tester.ensureVisible(_delete);
      await tester.tap(_delete);
      await tester.pump();

      expect(find.bySemanticsLabel(RegExp('Excluindo')), findsOneWidget);
      expect(deleteButton(tester).onPressed, isNull);
      pending.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('deve aguentar a fonte em 200%', (tester) async {
      tester.usePhoneScreen(textScale: 2);
      await pumpView(tester);

      await fillIn(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('deve passar nas verificações de acessibilidade', (tester) async {
      tester.view
        ..physicalSize = const Size(800, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      await pumpView(tester);
      await fillIn(tester);
      // O botão ativado troca de cor com uma animação.
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  });
}
