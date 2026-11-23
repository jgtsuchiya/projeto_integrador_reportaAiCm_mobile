import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/domain/models/client_registration.dart';
import 'package:reportaai_cm/features/auth/domain/models/registration_result.dart';
import 'package:reportaai_cm/features/auth/domain/models/sign_in_result.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/views/login_view.dart';
import 'package:reportaai_cm/features/auth/presentation/views/registration_view.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';
import '../../../../support/pump_app.dart';

const _email = 'maria.silva@exemplo.com';
const _password = 'senha-forte-1';

final Finder _nameField = find.widgetWithText(TextFormField, 'Nome completo');
final Finder _emailField = find.widgetWithText(TextFormField, 'E-mail');
final Finder _passwordField = find.widgetWithText(TextFormField, 'Senha');
final Finder _cpfField = find.widgetWithText(TextFormField, 'CPF');
final Finder _phoneField = find.widgetWithText(TextFormField, 'Telefone');
final Finder _birthDateField = find.widgetWithText(TextFormField, 'Data de nascimento');
final Finder _createButton = find.widgetWithText(FilledButton, 'Criar conta');

void main() {
  group('RegistrationView', () {
    late AuthFakes fakes;

    setUp(() => fakes = AuthFakes());

    /// Abre o cadastro sozinho, sem as rotas, depois da abertura sem sessão.
    Future<void> pumpView(WidgetTester tester) async {
      await tester.pumpApp(const RegistrationView(), overrides: fakes.overrides);
      await tester.pump();
    }

    /// Abre o cadastro por cima de um login de mentira, como o "Criar conta" do login. Devolve o
    /// que o cadastro devolve ao login quando fecha.
    Future<List<Object?>> pumpOverLogin(WidgetTester tester) async {
      final results = <Object?>[];
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () async => results.add(await context.push<Object?>('/cadastro')),
                child: const Text('Abrir o cadastro'),
              ),
            ),
          ),
          GoRoute(path: '/cadastro', builder: (_, _) => const RegistrationView()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpRouter(router, overrides: fakes.overrides);
      await tester.pump();
      await tester.tap(find.text('Abrir o cadastro'));
      await tester.pumpAndSettle();

      return results;
    }

    /// Preenche os campos como o usuário, digitando só os dígitos nos campos com máscara.
    Future<void> fillIn(WidgetTester tester, {String email = _email}) async {
      await tester.enterText(_nameField, 'Maria da Silva');
      await tester.enterText(_emailField, email);
      await tester.enterText(_passwordField, _password);
      await tester.enterText(_cpfField, '52998224725');
      await tester.enterText(_phoneField, '44999998888');
      await tester.enterText(_birthDateField, '20051990');
    }

    Future<void> create(WidgetTester tester) async {
      await tester.ensureVisible(_createButton);
      await tester.tap(_createButton);
      await tester.pump();
    }

    String textOf(WidgetTester tester, Finder field) => tester
        .widget<EditableText>(find.descendant(of: field, matching: find.byType(EditableText)))
        .controller
        .text;

    TextField textFieldOf(WidgetTester tester, Finder field) =>
        tester.widget<TextField>(find.descendant(of: field, matching: find.byType(TextField)));

    Finder errorBelow(Finder field, String message) =>
        find.descendant(of: field, matching: find.text(message));

    /// Os atalhos do e-mail que já tem conta ficam no alto do formulário: a tela rola até eles.
    Future<void> tapShortcut(WidgetTester tester, String label) async {
      final shortcut = find.widgetWithText(TextButton, label);
      await tester.ensureVisible(shortcut);
      await tester.pumpAndSettle();
      await tester.tap(shortcut);
      await tester.pumpAndSettle();
    }

    VoidCallback? onCreate(WidgetTester tester) =>
        tester.widget<FilledButton>(_createButton).onPressed;

    Iterable<MethodCall> finishAutofillCalls(WidgetTester tester) =>
        tester.testTextInput.log.where((call) => call.method == 'TextInput.finishAutofillContext');

    testWidgets('deve mostrar os campos, a regra da senha e o aviso do e-mail', (tester) async {
      await pumpView(tester);

      for (final field in [
        _nameField,
        _emailField,
        _passwordField,
        _cpfField,
        _phoneField,
        _birthDateField,
      ]) {
        expect(field, findsOneWidget);
      }
      expect(find.text('A senha precisa ter:'), findsOneWidget);
      expect(find.textContaining('vamos mandar um link para o seu e-mail'), findsOneWidget);
      expect(_createButton, findsOneWidget);
    });

    group('campos', () {
      testWidgets('deve pôr a máscara no CPF, no telefone e na data', (tester) async {
        await pumpView(tester);

        await fillIn(tester);

        expect(textOf(tester, _cpfField), '529.982.247-25');
        expect(textOf(tester, _phoneField), '(44) 99999-8888');
        expect(textOf(tester, _birthDateField), '20/05/1990');
      });

      testWidgets('deve aceitar o CPF colado com a pontuação', (tester) async {
        await pumpView(tester);

        await tester.enterText(_cpfField, '529.982.247-25');

        expect(textOf(tester, _cpfField), '529.982.247-25');
      });

      testWidgets('deve usar o teclado de cada campo', (tester) async {
        await pumpView(tester);

        expect(textFieldOf(tester, _nameField).textCapitalization, TextCapitalization.words);
        expect(textFieldOf(tester, _emailField).keyboardType, TextInputType.emailAddress);
        expect(textFieldOf(tester, _cpfField).keyboardType, TextInputType.number);
        expect(textFieldOf(tester, _phoneField).keyboardType, TextInputType.phone);
        expect(textFieldOf(tester, _birthDateField).keyboardType, TextInputType.number);
        expect(textFieldOf(tester, _birthDateField).textInputAction, TextInputAction.done);
      });

      testWidgets('deve deixar o gerenciador de senhas preencher e salvar a senha nova', (
        tester,
      ) async {
        await pumpView(tester);

        expect(textFieldOf(tester, _nameField).autofillHints, [AutofillHints.name]);
        expect(textFieldOf(tester, _emailField).autofillHints, [AutofillHints.email]);
        expect(textFieldOf(tester, _passwordField).autofillHints, [AutofillHints.newPassword]);
        expect(textFieldOf(tester, _phoneField).autofillHints, [AutofillHints.telephoneNumber]);
        expect(
          tester.widget<AutofillGroup>(find.byType(AutofillGroup)).onDisposeAction,
          AutofillContextAction.cancel,
        );
      });

      testWidgets('deve ocultar a senha e mostrar pelo botão, sem sugestão do teclado', (
        tester,
      ) async {
        await pumpView(tester);
        await tester.enterText(_passwordField, _password);
        expect(textFieldOf(tester, _passwordField).obscureText, isTrue);

        await tester.tap(find.byTooltip('Mostrar senha'));
        await tester.pump();

        final password = textFieldOf(tester, _passwordField);
        expect(password.obscureText, isFalse);
        expect(password.enableSuggestions, isFalse);
        expect(password.enableIMEPersonalizedLearning, isFalse);
      });
    });

    group('conferência antes de enviar (RM11)', () {
      testWidgets('deve pedir cada campo embaixo dele, sem chamar a API', (tester) async {
        await pumpView(tester);

        await create(tester);

        for (final (field, message) in [
          (_nameField, 'Informe o nome.'),
          (_emailField, 'Informe o e-mail.'),
          (_passwordField, 'Informe a senha.'),
          (_cpfField, 'Informe o CPF.'),
          (_phoneField, 'Informe o telefone.'),
          (_birthDateField, 'Informe a data de nascimento.'),
        ]) {
          expect(errorBelow(field, message), findsOneWidget, reason: message);
        }
        expect(fakes.registration.calls, isEmpty);
      });

      testWidgets('deve recusar a senha fora da regra e o CPF inválido', (tester) async {
        await pumpView(tester);
        await fillIn(tester);
        await tester.enterText(_passwordField, 'curta1');
        await tester.enterText(_cpfField, '11111111111');

        await create(tester);

        expect(
          errorBelow(_passwordField, 'A senha deve ter de 8 a 128 caracteres.'),
          findsOneWidget,
        );
        expect(errorBelow(_cpfField, 'CPF inválido.'), findsOneWidget);
        expect(fakes.registration.calls, isEmpty);
      });

      testWidgets('deve tirar o erro do campo quando o usuário o edita', (tester) async {
        await pumpView(tester);
        await create(tester);

        await tester.enterText(_cpfField, '5');
        await tester.pump();

        expect(find.text('Informe o CPF.'), findsNothing);
        expect(find.text('Informe o telefone.'), findsOneWidget);
      });
    });

    group('respostas do cadastro', () {
      testWidgets('deve enviar só os dígitos e entrar sozinho com o 201 (RM12)', (tester) async {
        await pumpView(tester);
        await fillIn(tester);

        await create(tester);

        expect(
          fakes.registration.calls.single,
          const ClientRegistration(
            name: 'Maria da Silva',
            email: _email,
            password: _password,
            cpf: '52998224725',
            phone: '44999998888',
            birthDate: '1990-05-20',
          ),
        );
        expect(fakes.auth.signInCalls.single, (email: _email, password: _password));
        expect(tester.container().read(authControllerProvider), AuthAuthenticated(clientProfile));
        // O gerenciador de senhas oferece salvar a senha da conta nova.
        expect(finishAutofillCalls(tester).single.arguments, isTrue);
      });

      testWidgets('deve mostrar a mensagem de cada campo do 400 embaixo dele', (tester) async {
        fakes.registration.result = const RegistrationFieldErrors({
          RegistrationField.phone: 'Telefone inválido. Informe o DDD e o número.',
          RegistrationField.birthDate: 'A data de nascimento precisa estar no passado.',
        });
        await pumpView(tester);
        await fillIn(tester);

        await create(tester);

        expect(
          errorBelow(_phoneField, 'Telefone inválido. Informe o DDD e o número.'),
          findsOneWidget,
        );
        expect(
          errorBelow(_birthDateField, 'A data de nascimento precisa estar no passado.'),
          findsOneWidget,
        );
        expect(fakes.auth.signInCalls, isEmpty);
        expect(finishAutofillCalls(tester), isEmpty);
      });

      testWidgets('deve mostrar o 409 do CPF no campo do CPF, sem os atalhos', (tester) async {
        fakes.registration.result = const RegistrationFieldErrors({
          RegistrationField.cpf: 'CPF já cadastrado.',
        }, alreadyInUse: RegistrationField.cpf);
        await pumpView(tester);
        await fillIn(tester);

        await create(tester);

        expect(errorBelow(_cpfField, 'CPF já cadastrado.'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Entrar'), findsNothing);
      });

      group('409 do e-mail', () {
        setUp(() {
          fakes.registration.result = const RegistrationFieldErrors({
            RegistrationField.email: 'E-mail já cadastrado.',
          }, alreadyInUse: RegistrationField.email);
        });

        testWidgets('deve mostrar a mensagem da API no e-mail, com os atalhos', (tester) async {
          await pumpView(tester);
          await fillIn(tester);

          await create(tester);

          expect(errorBelow(_emailField, 'E-mail já cadastrado.'), findsOneWidget);
          expect(find.widgetWithText(TextButton, 'Entrar'), findsOneWidget);
          expect(find.widgetWithText(TextButton, 'Esqueci minha senha'), findsOneWidget);
        });

        testWidgets('deve voltar ao login com o e-mail pelo "Entrar"', (tester) async {
          final results = await pumpOverLogin(tester);
          await fillIn(tester, email: ' $_email ');
          await create(tester);

          await tapShortcut(tester, 'Entrar');

          expect(find.byType(RegistrationView), findsNothing);
          expect(results, [const LoginPrefill(email: _email)]);
        });

        testWidgets('deve voltar ao login e pedir o "Esqueci minha senha" com o e-mail', (
          tester,
        ) async {
          final results = await pumpOverLogin(tester);
          await fillIn(tester);
          await create(tester);

          await tapShortcut(tester, 'Esqueci minha senha');

          expect(results, [const LoginPrefill(email: _email, openForgotPassword: true)]);
        });

        testWidgets('deve tirar os atalhos quando o e-mail muda', (tester) async {
          await pumpView(tester);
          await fillIn(tester);
          await create(tester);

          await tester.enterText(_emailField, 'outro@exemplo.com');
          await tester.pump();

          expect(find.widgetWithText(TextButton, 'Entrar'), findsNothing);
        });
      });

      testWidgets('deve desativar o "Criar conta" com a contagem do 429 e voltar sozinho', (
        tester,
      ) async {
        fakes.registration.result = const RegistrationRateLimited(retryAfter: Duration(seconds: 2));
        await pumpView(tester);
        await fillIn(tester);

        await create(tester);

        expect(find.text('Muitas tentativas. Tente de novo em 2 s.'), findsOneWidget);
        expect(onCreate(tester), isNull);

        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Muitas tentativas. Tente de novo em 1 s.'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        expect(find.textContaining('Muitas tentativas'), findsNothing);
        expect(onCreate(tester), isNotNull);
      });

      for (final (description, error) in [
        ('sem conexão', const NetworkException()),
        ('no 5xx', const ServerException(statusCode: 500)),
      ]) {
        testWidgets('deve mostrar a mensagem $description e manter os campos', (tester) async {
          fakes.registration.error = error;
          await pumpView(tester);
          await fillIn(tester);

          await create(tester);

          expect(find.text(error.message), findsOneWidget);
          expect(textOf(tester, _emailField), _email);
          expect(textOf(tester, _passwordField), _password);
          expect(textOf(tester, _cpfField), '529.982.247-25');
        });
      }

      testWidgets('deve mostrar o carregando e não enviar de novo no segundo toque', (
        tester,
      ) async {
        final pending = fakes.registration.pending = Completer<RegistrationResult>();
        await pumpView(tester);
        await fillIn(tester);

        await create(tester);
        await tester.tap(_createButton, warnIfMissed: false);
        await tester.pump();

        expect(find.bySemanticsLabel(RegExp('Carregando')), findsOneWidget);
        expect(fakes.registration.calls, hasLength(1));

        pending.complete(const RegistrationFieldErrors({RegistrationField.cpf: 'CPF inválido.'}));
        await tester.pump();
      });

      testWidgets(
        'deve voltar ao login com o e-mail e o aviso quando o login automático falha (RM12)',
        (tester) async {
          fakes.auth.signInError = const NetworkException();
          final results = await pumpOverLogin(tester);
          await fillIn(tester);

          await create(tester);
          await tester.pumpAndSettle();

          expect(results, [
            const LoginPrefill(
              email: _email,
              notice: 'Sua conta foi criada. Entre com o e-mail e a senha.',
            ),
          ]);
          // A conta existe com esta senha: o gerenciador de senhas oferece salvar. Depois, o
          // AutofillGroup da tela que fechou termina o contexto dele, sem salvar.
          expect(finishAutofillCalls(tester).first.arguments, isTrue);
          expect(tester.container().read(authControllerProvider), const AuthUnauthenticated());
        },
      );

      testWidgets('deve voltar ao login quando o login automático é recusado (RM12)', (
        tester,
      ) async {
        fakes.auth.signInResult = const SignInWrongCredentials();
        final results = await pumpOverLogin(tester);
        await fillIn(tester);

        await create(tester);
        await tester.pumpAndSettle();

        expect(results.single, isA<LoginPrefill>());
      });
    });

    group('leitor de tela', () {
      testWidgets('deve ler o rótulo dos campos', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpView(tester);

        expect(
          tester.getSemantics(find.descendant(of: _cpfField, matching: find.byType(TextField))),
          isSemantics(label: 'CPF', isTextField: true),
        );
        expect(
          tester.getSemantics(
            find.descendant(of: _passwordField, matching: find.byType(TextField)),
          ),
          isSemantics(label: 'Senha', isTextField: true, isObscured: true),
        );
        semantics.dispose();
      });

      testWidgets('deve anunciar o aviso geral', (tester) async {
        fakes.registration.error = const NetworkException();
        final semantics = tester.ensureSemantics();
        await pumpView(tester);
        await fillIn(tester);

        await create(tester);

        expect(
          tester.getSemantics(find.text(NetworkException.defaultMessage)),
          isSemantics(isLiveRegion: true),
        );
        semantics.dispose();
      });
    });

    testWidgets('deve aguentar a fonte em 200%, com os erros dos campos', (tester) async {
      tester.usePhoneScreen(textScale: 2);
      await pumpView(tester);

      await create(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Informe a data de nascimento.'), findsOneWidget);
    });

    testWidgets('deve passar nas verificações de acessibilidade', (tester) async {
      fakes.registration.result = const RegistrationFieldErrors({
        RegistrationField.email: 'E-mail já cadastrado.',
      }, alreadyInUse: RegistrationField.email);
      // Uma tela alta, com o formulário inteiro à vista: um botão cortado pela rolagem
      // reprovaria o tamanho do toque sem ser um problema da tela.
      tester.view
        ..physicalSize = const Size(800, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      await pumpView(tester);
      await fillIn(tester);
      await create(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  });
}
