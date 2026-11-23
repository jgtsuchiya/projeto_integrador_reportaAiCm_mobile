import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/routes.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/domain/models/client_registration.dart';
import 'package:reportaai_cm/features/auth/domain/models/registration_result.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/email_verification_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/view_models/forgot_password_view_model.dart';
import 'package:reportaai_cm/features/auth/presentation/view_models/registration_view_model.dart';
import 'package:reportaai_cm/features/auth/presentation/views/forgot_password_view.dart';
import 'package:reportaai_cm/features/auth/presentation/views/login_view.dart';
import 'package:reportaai_cm/features/auth/presentation/views/registration_view.dart';
import 'package:reportaai_cm/features/home/presentation/views/home_view.dart';

import '../support/app_flow.dart';
import '../support/app_lifecycle.dart';
import '../support/auth_fakes.dart';
import '../support/fake_profile_repository.dart';

const _email = 'maria.silva@exemplo.com';
const _password = 'senha-forte-1';

final Finder _emailField = find.widgetWithText(TextFormField, 'E-mail');
final Finder _passwordField = find.widgetWithText(TextFormField, 'Senha');
final Finder _verifyEmail = find.text('Confirme o seu e-mail');

/// Os fluxos do épico de cadastro e recuperação de acesso de ponta a ponta, com o app inteiro: as
/// rotas, as telas e o `AuthController` de verdade, e só a sessão e os repositórios trocados pelos
/// fakes. Os detalhes de cada tela ficam nos testes dela.
void main() {
  group('Fluxo do cadastro e da recuperação de acesso', () {
    late AuthFakes fakes;

    setUp(() => fakes = AuthFakes());

    group('cadastro', () {
      testWidgets(
        'deve criar a conta, entrar sozinho e abrir a tela inicial com o aviso do e-mail (RM12)',
        (tester) async {
          final routes = await openWholeApp(tester, fakes);
          await tester.pumpAndSettle();

          await _tapAndSettle(tester, find.text('Criar conta'));
          expect(find.byType(RegistrationView), findsOneWidget);
          await _fillInRegistration(tester);
          await _tapAndSettle(tester, find.widgetWithText(FilledButton, 'Criar conta'));

          expect(routes, [AppRoutes.splash, AppRoutes.login, AppRoutes.register, AppRoutes.home]);
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
          expect(fakes.auth.signInCalls, [(email: _email, password: _password)]);
          expect(find.text('Olá, Maria'), findsOneWidget);
          expect(_verifyEmail, findsOneWidget);
          // O cadastro já mandou o link: o reenvio espera 1 minuto (RM14).
          expect(find.textContaining('Reenviar e-mail em'), findsOneWidget);
          // O redirect trocou a pilha: o "voltar" não volta ao cadastro.
          await expectBackClosesTheApp(tester);
          await tester.pump(EmailVerificationController.resendInterval);
        },
      );

      testWidgets('deve voltar ao login pelo atalho "Entrar" do e-mail que já tem conta', (
        tester,
      ) async {
        fakes.registration.result = const RegistrationFieldErrors({
          RegistrationField.email: 'E-mail já cadastrado.',
        }, alreadyInUse: RegistrationField.email);
        final routes = await openWholeApp(tester, fakes);
        await tester.pumpAndSettle();
        await _tapAndSettle(tester, find.text('Criar conta'));
        await _fillInRegistration(tester);
        await _tapAndSettle(tester, find.widgetWithText(FilledButton, 'Criar conta'));
        expect(find.text('E-mail já cadastrado.'), findsOneWidget);

        await _tapAndSettle(tester, find.widgetWithText(TextButton, 'Entrar'));

        expect(routes, [AppRoutes.splash, AppRoutes.login, AppRoutes.register, AppRoutes.login]);
        expect(find.byType(LoginView), findsOneWidget);
        expect(_textOf(tester, _emailField), _email);
        expect(fakes.auth.signInCalls, isEmpty);
      });

      testWidgets(
        'deve abrir o "Esqueci minha senha" pelo atalho do e-mail que já tem conta, e o "voltar" '
        'volta ao login',
        (tester) async {
          fakes.registration.result = const RegistrationFieldErrors({
            RegistrationField.email: 'E-mail já cadastrado.',
          }, alreadyInUse: RegistrationField.email);
          final routes = await openWholeApp(tester, fakes);
          await tester.pumpAndSettle();
          await _tapAndSettle(tester, find.text('Criar conta'));
          await _fillInRegistration(tester);
          await _tapAndSettle(tester, find.widgetWithText(FilledButton, 'Criar conta'));

          await _tapAndSettle(tester, find.widgetWithText(TextButton, 'Esqueci minha senha'));

          expect(find.byType(ForgotPasswordView), findsOneWidget);
          expect(_textOf(tester, _emailField), _email);

          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();

          expect(routes, [
            AppRoutes.splash,
            AppRoutes.login,
            AppRoutes.register,
            AppRoutes.login,
            AppRoutes.forgotPassword,
            AppRoutes.login,
          ]);
          expect(find.byType(LoginView), findsOneWidget);
        },
      );

      testWidgets(
        'deve levar ao login com o e-mail e o aviso quando o login automático falha, e entrar '
        'em seguida (RM12)',
        (tester) async {
          fakes.auth.signInError = const NetworkException();
          final routes = await openWholeApp(tester, fakes);
          await tester.pumpAndSettle();
          await _tapAndSettle(tester, find.text('Criar conta'));
          await _fillInRegistration(tester);

          await _tapAndSettle(tester, find.widgetWithText(FilledButton, 'Criar conta'));

          expect(find.byType(LoginView), findsOneWidget);
          expect(_textOf(tester, _emailField), _email);
          expect(find.text(RegistrationViewModel.accountCreatedMessage), findsOneWidget);

          fakes.auth.signInError = null;
          await tester.enterText(_passwordField, _password);
          await _tapAndSettle(tester, find.text('Entrar'));

          expect(routes, [
            AppRoutes.splash,
            AppRoutes.login,
            AppRoutes.register,
            AppRoutes.login,
            AppRoutes.home,
          ]);
          expect(find.text('Olá, Maria'), findsOneWidget);
          await tester.pump(EmailVerificationController.resendInterval);
        },
      );
    });

    group('"Esqueci minha senha"', () {
      testWidgets(
        'deve pedir o link com o e-mail do login, mostrar a mensagem e voltar ao login (RM13)',
        (tester) async {
          final routes = await openWholeApp(tester, fakes);
          await tester.pumpAndSettle();
          await tester.enterText(_emailField, _email);

          await _tapAndSettle(tester, find.text('Esqueci minha senha'));
          expect(_textOf(tester, _emailField), _email);
          await tester.tap(find.widgetWithText(FilledButton, 'Enviar link'));
          await tester.pump();

          expect(fakes.auth.passwordResetCalls, [_email]);
          expect(find.text(ForgotPasswordViewModel.sentMessage), findsOneWidget);
          expect(find.text('Enviar de novo em 60 s'), findsOneWidget);

          await _tapAndSettle(tester, find.text('Voltar ao login'));

          expect(routes, [
            AppRoutes.splash,
            AppRoutes.login,
            AppRoutes.forgotPassword,
            AppRoutes.login,
          ]);
          expect(find.byType(LoginView), findsOneWidget);
          expect(_textOf(tester, _emailField), _email);
        },
      );
    });

    group('aviso do e-mail (RM14)', () {
      setUp(() => fakes = AuthFakes(signedIn: true));

      testWidgets('deve reenviar o link pela tela inicial e começar a contagem', (tester) async {
        await openWholeApp(tester, fakes);
        await tester.pumpAndSettle();
        expect(find.byType(HomeView), findsOneWidget);

        await tester.tap(find.text('Reenviar e-mail'));
        await tester.pump();

        expect(fakes.profile.resendCalls, 1);
        expect(find.text(EmailVerificationController.sentMessage), findsOneWidget);
        expect(find.text('Reenviar e-mail em 60 s'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Reenviar e-mail em 59 s'), findsOneWidget);

        await tester.pump(EmailVerificationController.resendInterval);
        expect(find.text('Reenviar e-mail'), findsOneWidget);
      });

      testWidgets(
        'deve tirar o aviso ao voltar do segundo plano com o e-mail confirmado, sem puxar para '
        'atualizar',
        (tester) async {
          await openWholeApp(tester, fakes);
          await tester.pumpAndSettle();
          expect(_verifyEmail, findsOneWidget);

          // O Client confirmou o e-mail no navegador.
          fakes.profile.result = clientProfileWith(emailVerifiedAt: DateTime.utc(2026, 10, 5, 12));
          tester.leaveAndComeBack();
          await tester.pumpAndSettle();

          expect(_verifyEmail, findsNothing);
          expect(find.text('Olá, Maria'), findsOneWidget);
          await tester.pump(EmailVerificationController.resumeRefreshInterval);
        },
      );
    });
  });
}

/// Preenche o cadastro como o usuário, digitando só os dígitos nos campos com máscara.
Future<void> _fillInRegistration(WidgetTester tester) async {
  for (final (label, text) in [
    ('Nome completo', 'Maria da Silva'),
    ('E-mail', _email),
    ('Senha', _password),
    ('CPF', '52998224725'),
    ('Telefone', '44999998888'),
    ('Data de nascimento', '20051990'),
  ]) {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
  }
}

/// Toca no [target], rolando a tela até ele, e espera a tela parar de mudar.
Future<void> _tapAndSettle(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

String _textOf(WidgetTester tester, Finder field) => tester
    .widget<EditableText>(find.descendant(of: field, matching: find.byType(EditableText)))
    .controller
    .text;
