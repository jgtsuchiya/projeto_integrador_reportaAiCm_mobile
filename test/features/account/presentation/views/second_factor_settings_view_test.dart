import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/confirmation_password.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/second_factor_settings_view_model.dart';
import 'package:reportaai_cm/features/account/presentation/views/second_factor_settings_view.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/widgets/email_verification_notice.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';
import '../../../../support/pump_app.dart';

const _password = 'senha-forte-1';

final Finder _passwordField = find.widgetWithText(TextFormField, 'Senha atual');
final Finder _enable = find.widgetWithText(FilledButton, 'Ativar a verificação');
final Finder _disable = find.widgetWithText(FilledButton, 'Desativar a verificação');

void main() {
  group('SecondFactorSettingsView', () {
    late AuthFakes fakes;

    setUp(() {
      fakes = AuthFakes(signedIn: true);
      fakes.profile.result = clientProfileWith(emailVerifiedAt: emailVerifiedAt);
    });

    Future<void> pumpView(WidgetTester tester) => tester.pumpPushed(
      const SecondFactorSettingsView(),
      overrides: fakes.overrides,
      beforePush: AuthFakes.startAuth,
    );

    bool mfaEnabled(WidgetTester tester) =>
        switch (tester.container().read(authControllerProvider)) {
          AuthAuthenticated(:final profile) => profile.mfaEnabled,
          _ => throw StateError('O Client saiu.'),
        };

    Future<void> tapAndSettle(WidgetTester tester, Finder target) async {
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    testWidgets('deve mostrar o estado e pedir a senha só depois de mexer no interruptor', (
      tester,
    ) async {
      await pumpView(tester);

      expect(find.text('Desativada'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
      expect(_passwordField, findsNothing);

      await tapAndSettle(tester, find.byType(SwitchListTile));

      expect(_passwordField, findsOneWidget);
      expect(find.textContaining('os outros aparelhos saem da conta'), findsOneWidget);
      expect(_enable, findsOneWidget);

      await tapAndSettle(tester, find.byType(SwitchListTile));

      expect(_passwordField, findsNothing);
    });

    testWidgets('deve ativar com a senha, avisar e voltar', (tester) async {
      await pumpView(tester);

      await tapAndSettle(tester, find.byType(SwitchListTile));
      await tester.enterText(_passwordField, _password);
      await tapAndSettle(tester, _enable);

      expect(fakes.profile.setMfaCalls, [(enabled: true, password: _password)]);
      expect(mfaEnabled(tester), isTrue);
      expect(find.text(SecondFactorSettingsViewModel.enabledMessage), findsOneWidget);
      expect(find.text(screenBelow), findsOneWidget);
    });

    testWidgets('deve desativar com a senha', (tester) async {
      fakes.profile.result = clientProfileWith(emailVerifiedAt: emailVerifiedAt, mfaEnabled: true);
      await pumpView(tester);
      expect(find.text('Ativada'), findsOneWidget);

      await tapAndSettle(tester, find.byType(SwitchListTile));
      expect(find.textContaining('volta a pedir só o e-mail e a senha'), findsOneWidget);
      await tester.enterText(_passwordField, _password);
      await tapAndSettle(tester, _disable);

      expect(mfaEnabled(tester), isFalse);
      expect(find.text(SecondFactorSettingsViewModel.disabledMessage), findsOneWidget);
    });

    testWidgets('deve mostrar a senha incorreta no campo e apagá-lo (422, RM15)', (tester) async {
      fakes.profile.setMfaError = const BusinessRuleException(
        message: 'Senha incorreta.',
        field: 'password',
      );
      await pumpView(tester);

      await tapAndSettle(tester, find.byType(SwitchListTile));
      await tester.enterText(_passwordField, 'errada-1');
      await tapAndSettle(tester, _enable);

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
      expect(mfaEnabled(tester), isFalse);
      expect(find.byType(SecondFactorSettingsView), findsOneWidget);
    });

    testWidgets('deve mostrar o erro sem conexão', (tester) async {
      fakes.profile.setMfaError = const NetworkException();
      await pumpView(tester);

      await tapAndSettle(tester, find.byType(SwitchListTile));
      await tester.enterText(_passwordField, _password);
      await tapAndSettle(tester, _enable);

      expect(find.text(NetworkException.defaultMessage), findsOneWidget);
    });

    testWidgets('deve mostrar o aviso do e-mail no lugar do interruptor sem a confirmação', (
      tester,
    ) async {
      fakes.profile.result = clientProfile;
      await pumpView(tester);

      expect(find.byType(EmailVerificationNotice), findsOneWidget);
      expect(find.text('Confirme o seu e-mail'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
    });

    testWidgets('deve deixar desativar mesmo sem o e-mail confirmado', (tester) async {
      fakes.profile.result = clientProfileWith(mfaEnabled: true);
      await pumpView(tester);

      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(find.byType(EmailVerificationNotice), findsNothing);
    });

    testWidgets('deve aguentar a fonte em 200%, com a senha pedida', (tester) async {
      tester.usePhoneScreen(textScale: 2);
      await pumpView(tester);

      await tapAndSettle(tester, find.byType(SwitchListTile));
      await tapAndSettle(tester, _enable);

      expect(tester.takeException(), isNull);
      expect(find.text(ConfirmationPasswordMessages.missing), findsOneWidget);
    });
  });
}
