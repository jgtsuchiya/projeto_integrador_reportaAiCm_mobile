import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/change_password_view_model.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/confirmation_password.dart';
import 'package:reportaai_cm/features/account/presentation/views/change_password_view.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/widgets/password_rules.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';
import '../../../../support/pump_app.dart';

const _current = 'senha-forte-1';
const _new = 'senha-nova-2';

final Finder _currentField = find.widgetWithText(TextFormField, 'Senha atual');
final Finder _newField = find.widgetWithText(TextFormField, 'Senha nova');
final Finder _confirmationField = find.widgetWithText(TextFormField, 'Repita a senha nova');
final Finder _submit = find.widgetWithText(FilledButton, 'Trocar senha');

void main() {
  group('ChangePasswordView', () {
    late AuthFakes fakes;

    setUp(() => fakes = AuthFakes(signedIn: true));

    Future<void> pumpView(WidgetTester tester) => tester.pumpPushed(
      const ChangePasswordView(),
      overrides: fakes.overrides,
      beforePush: AuthFakes.startAuth,
    );

    EditableText editable(WidgetTester tester, Finder field) => tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );

    Future<void> fillIn(
      WidgetTester tester, {
      String current = _current,
      String newPassword = _new,
      String? confirmation,
    }) async {
      await tester.enterText(_currentField, current);
      await tester.enterText(_newField, newPassword);
      await tester.enterText(_confirmationField, confirmation ?? newPassword);
    }

    Future<void> submit(WidgetTester tester) async {
      await tester.ensureVisible(_submit);
      await tester.tap(_submit);
      await tester.pumpAndSettle();
    }

    testWidgets('deve ter os três campos, a regra e o aviso dos outros aparelhos (RM16)', (
      tester,
    ) async {
      await pumpView(tester);

      expect(_currentField, findsOneWidget);
      expect(_newField, findsOneWidget);
      expect(_confirmationField, findsOneWidget);
      expect(find.byType(PasswordRules), findsOneWidget);
      expect(find.textContaining('os outros aparelhos saem da conta'), findsOneWidget);
      expect(editable(tester, _currentField).autofillHints, [AutofillHints.password]);
      expect(editable(tester, _newField).autofillHints, [AutofillHints.newPassword]);
      expect(editable(tester, _newField).obscureText, isTrue);
    });

    testWidgets('deve mostrar e ocultar a senha', (tester) async {
      await pumpView(tester);

      await tester.tap(find.byTooltip('Mostrar senha').first);
      await tester.pump();

      expect(editable(tester, _currentField).obscureText, isFalse);
      expect(find.byTooltip('Ocultar senha'), findsOneWidget);
    });

    testWidgets('deve trocar a senha, avisar e voltar, com o aparelho logado (204)', (
      tester,
    ) async {
      final autofillCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.textInput, (
        call,
      ) async {
        autofillCalls.add(call);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.textInput,
          null,
        ),
      );
      await pumpView(tester);

      await fillIn(tester);
      await submit(tester);

      expect(fakes.profile.changePasswordCalls, [(currentPassword: _current, newPassword: _new)]);
      expect(find.text(ChangePasswordViewModel.changedMessage), findsOneWidget);
      expect(find.text(screenBelow), findsOneWidget);
      expect(tester.container().read(authControllerProvider), AuthAuthenticated(clientProfile));
      // O gerenciador de senhas oferece atualizar a senha guardada.
      expect(
        autofillCalls.map((call) => (call.method, call.arguments)),
        contains(('TextInput.finishAutofillContext', true)),
      );
    });

    testWidgets('deve mostrar a senha atual incorreta no campo e apagá-lo (422, RM15)', (
      tester,
    ) async {
      fakes.profile.changePasswordError = const BusinessRuleException(
        message: 'Senha incorreta.',
        field: 'currentPassword',
      );
      await pumpView(tester);

      await fillIn(tester, current: 'errada-1');
      await submit(tester);

      expect(find.text(ConfirmationPasswordMessages.incorrect), findsOneWidget);
      expect(editable(tester, _currentField).controller.text, isEmpty);
      expect(editable(tester, _newField).controller.text, _new);
      expect(find.byType(ChangePasswordView), findsOneWidget);
      expect(tester.container().read(authControllerProvider), AuthAuthenticated(clientProfile));
    });

    testWidgets('deve mostrar o 400 da senha nova embaixo dela', (tester) async {
      fakes.profile.changePasswordError = const ValidationException(
        fieldErrors: [FieldError(field: 'newPassword', message: 'A senha é fraca.')],
      );
      await pumpView(tester);

      await fillIn(tester);
      await submit(tester);

      expect(find.text('A senha é fraca.'), findsOneWidget);
    });

    testWidgets('deve enviar pelo "concluir" do teclado na confirmação', (tester) async {
      await pumpView(tester);

      await fillIn(tester);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(fakes.profile.changePasswordCalls, hasLength(1));
    });

    testWidgets('deve recusar a confirmação diferente antes de enviar', (tester) async {
      await pumpView(tester);

      await fillIn(tester, confirmation: 'outra-senha-3');
      await submit(tester);

      expect(find.text(ChangePasswordViewModel.confirmationMismatchMessage), findsOneWidget);
      expect(fakes.profile.changePasswordCalls, isEmpty);

      await tester.enterText(_confirmationField, _new);
      await tester.pump();
      expect(find.text(ChangePasswordViewModel.confirmationMismatchMessage), findsNothing);
    });

    testWidgets('deve mostrar o erro sem conexão e manter os campos', (tester) async {
      fakes.profile.changePasswordError = const NetworkException();
      await pumpView(tester);

      await fillIn(tester);
      await submit(tester);

      expect(find.text(NetworkException.defaultMessage), findsOneWidget);
      expect(editable(tester, _currentField).controller.text, _current);
    });

    testWidgets('deve aguentar a fonte em 200%, com os erros dos campos', (tester) async {
      tester.usePhoneScreen(textScale: 2);
      await pumpView(tester);

      await submit(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(ConfirmationPasswordMessages.missing), findsOneWidget);
    });
  });
}
