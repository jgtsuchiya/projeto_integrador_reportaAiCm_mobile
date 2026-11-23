import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/edit_profile_view_model.dart';
import 'package:reportaai_cm/features/account/presentation/views/edit_profile_view.dart';
import 'package:reportaai_cm/features/auth/domain/models/registration_validation.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/profile/domain/models/profile_changes.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';
import '../../../../support/pump_app.dart';

final Finder _nameField = find.widgetWithText(TextFormField, 'Nome completo');
final Finder _phoneField = find.widgetWithText(TextFormField, 'Telefone');
final Finder _birthDateField = find.widgetWithText(TextFormField, 'Data de nascimento');
final Finder _save = find.widgetWithText(FilledButton, 'Salvar');

void main() {
  group('EditProfileView', () {
    late AuthFakes fakes;

    setUp(() => fakes = AuthFakes(signedIn: true));

    Future<void> pumpView(WidgetTester tester) async {
      await tester.pumpPushed(
        const EditProfileView(),
        overrides: fakes.overrides,
        beforePush: AuthFakes.startAuth,
      );
    }

    String textOf(WidgetTester tester, Finder field) => tester
        .widget<EditableText>(find.descendant(of: field, matching: find.byType(EditableText)))
        .controller
        .text;

    FilledButton saveButton(WidgetTester tester) => tester.widget<FilledButton>(_save);

    Future<void> save(WidgetTester tester) async {
      // O "Salvar" acompanha os campos: o quadro depois da última letra o ativa.
      await tester.pump();
      await tester.ensureVisible(_save);
      await tester.tap(_save);
      await tester.pumpAndSettle();
    }

    AuthState auth(WidgetTester tester) => tester.container().read(authControllerProvider);

    testWidgets('deve abrir com os dados do perfil, e o e-mail e o CPF sem edição', (tester) async {
      await pumpView(tester);

      expect(textOf(tester, _nameField), 'Maria da Silva');
      expect(textOf(tester, _phoneField), '(44) 99999-8888');
      expect(textOf(tester, _birthDateField), '20/05/1990');
      expect(find.text('maria.silva@exemplo.com'), findsOneWidget);
      // O CPF continua mascarado (RM09).
      expect(find.text('***.982.247-**'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'E-mail'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'CPF'), findsNothing);
    });

    testWidgets('deve deixar o "Salvar" desativado sem mudança', (tester) async {
      await pumpView(tester);
      expect(saveButton(tester).onPressed, isNull);

      await tester.enterText(_nameField, 'Maria Souza');
      await tester.pump();
      expect(saveButton(tester).onPressed, isNotNull);

      await tester.enterText(_nameField, ' Maria da Silva ');
      await tester.pump();
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('deve salvar só o que mudou, mostrar os dados novos e voltar', (tester) async {
      await pumpView(tester);

      await tester.enterText(_nameField, 'Maria Souza');
      await tester.enterText(_phoneField, '43988887777');
      await save(tester);

      expect(fakes.profile.updateCalls, [
        const ProfileChanges(name: 'Maria Souza', phone: '43988887777'),
      ]);
      expect(
        auth(tester),
        AuthAuthenticated(clientProfileWith(name: 'Maria Souza', phone: '43988887777')),
      );
      expect(find.text(EditProfileViewModel.savedMessage), findsOneWidget);
      expect(find.text(screenBelow), findsOneWidget);
      expect(find.byType(EditProfileView), findsNothing);
    });

    testWidgets('deve mostrar o erro de cada campo antes de enviar (RM11)', (tester) async {
      await pumpView(tester);

      await tester.enterText(_nameField, '');
      await tester.enterText(_birthDateField, '2005');
      await save(tester);

      expect(find.text(RegistrationMessages.nameMissing), findsOneWidget);
      expect(find.text(RegistrationMessages.birthDateInvalid), findsOneWidget);
      expect(fakes.profile.updateCalls, isEmpty);

      await tester.enterText(_nameField, 'Maria');
      await tester.pump();
      expect(find.text(RegistrationMessages.nameMissing), findsNothing);
      expect(find.text(RegistrationMessages.birthDateInvalid), findsOneWidget);
    });

    testWidgets('deve mostrar o 400 da API embaixo do campo', (tester) async {
      fakes.profile.updateError = const ValidationException(
        fieldErrors: [FieldError(field: 'birthDate', message: 'Data de nascimento inválida.')],
      );
      await pumpView(tester);

      await tester.enterText(_birthDateField, '21061991');
      await save(tester);

      expect(find.text('Data de nascimento inválida.'), findsOneWidget);
      expect(find.byType(EditProfileView), findsOneWidget);
    });

    testWidgets('deve mostrar o erro sem conexão e manter os campos', (tester) async {
      fakes.profile.updateError = const NetworkException();
      await pumpView(tester);

      await tester.enterText(_nameField, 'Maria Souza');
      await save(tester);

      expect(find.text(NetworkException.defaultMessage), findsOneWidget);
      expect(textOf(tester, _nameField), 'Maria Souza');
      expect(auth(tester), AuthAuthenticated(clientProfile));
    });

    testWidgets('deve voltar sem perguntar quando nada mudou', (tester) async {
      await pumpView(tester);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text(screenBelow), findsOneWidget);
    });

    testWidgets('deve perguntar antes de descartar as alterações não salvas', (tester) async {
      await pumpView(tester);
      await tester.enterText(_nameField, 'Maria Souza');
      await tester.pump();

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Descartar as alterações?'), findsOneWidget);

      await tester.tap(find.text('Continuar editando'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileView), findsOneWidget);
      expect(textOf(tester, _nameField), 'Maria Souza');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();

      expect(find.text(screenBelow), findsOneWidget);
      expect(fakes.profile.updateCalls, isEmpty);
    });

    testWidgets('deve aguentar a fonte em 200%, com os erros dos campos', (tester) async {
      tester.usePhoneScreen(textScale: 2);
      await pumpView(tester);

      await tester.enterText(_phoneField, '');
      await save(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(RegistrationMessages.phoneMissing), findsOneWidget);
    });
  });
}
