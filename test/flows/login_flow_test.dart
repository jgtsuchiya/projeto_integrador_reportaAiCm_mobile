import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/routes.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/domain/models/sign_in_result.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/view_models/login_view_model.dart';
import 'package:reportaai_cm/features/auth/presentation/view_models/second_factor_view_model.dart';
import 'package:reportaai_cm/features/auth/presentation/views/login_view.dart';
import 'package:reportaai_cm/features/auth/presentation/views/second_factor_view.dart';
import 'package:reportaai_cm/features/auth/presentation/views/splash_view.dart';
import 'package:reportaai_cm/features/home/presentation/views/home_view.dart';

import '../support/app_flow.dart';
import '../support/auth_fakes.dart';
import '../support/fake_profile_repository.dart';
import '../support/sign_out.dart';

const _password = 'SenhaSecreta123';

final Finder _emailField = find.widgetWithText(TextFormField, 'E-mail');
final Finder _passwordField = find.widgetWithText(TextFormField, 'Senha');

/// Os fluxos do épico de login de ponta a ponta, com o app inteiro: as rotas, as telas e o
/// `AuthController` de verdade, e só a sessão e os repositórios trocados pelos fakes. Cada teste
/// segue o caminho do usuário, do "abrir o app" até a última tela, como o `client-flow.e2e-spec.ts`
/// do backend segue o do Client na API. Os detalhes de cada tela ficam nos testes dela.
void main() {
  group('Fluxo do login e da tela inicial', () {
    late AuthFakes fakes;

    setUp(() => fakes = AuthFakes());

    group('abertura sem sessão', () {
      testWidgets(
        'deve ir ao login e, depois do login, à tela inicial com os dados do Client (RM09)',
        (tester) async {
          final routes = await openWholeApp(tester, fakes);
          expect(find.byType(SplashView), findsOneWidget);

          await tester.pumpAndSettle();
          expect(find.byType(LoginView), findsOneWidget);
          await _signIn(tester, email: clientProfile.email);

          expect(routes, [AppRoutes.splash, AppRoutes.login, AppRoutes.home]);
          expect(fakes.auth.signInCalls, [(email: clientProfile.email, password: _password)]);
          expect(find.text('Olá, Maria'), findsOneWidget);
          expect(find.text(clientProfile.name), findsOneWidget);
          expect(find.text('***.982.247-**'), findsOneWidget);
          expect(find.textContaining(clientProfile.cpf!), findsNothing);
          await expectBackClosesTheApp(tester);
        },
      );
    });

    group('abertura com a sessão guardada', () {
      setUp(() => fakes = AuthFakes(signedIn: true));

      testWidgets('deve ir direto à tela inicial, sem passar pelo login (RM06)', (tester) async {
        final routes = await openWholeApp(tester, fakes);

        await tester.pumpAndSettle();

        expect(routes, [AppRoutes.splash, AppRoutes.home]);
        expect(fakes.auth.signInCalls, isEmpty);
        expect(find.text('Olá, Maria'), findsOneWidget);
        await expectBackClosesTheApp(tester);
      });

      testWidgets(
        'deve mostrar o erro sem rede, sem apagar a sessão, e entrar pelo "Tentar de novo" (RM06)',
        (tester) async {
          fakes.profile.error = const NetworkException();
          final routes = await openWholeApp(tester, fakes);
          await tester.pumpAndSettle();
          expect(find.byType(SplashView), findsOneWidget);
          expect(find.text('Não foi possível abrir a sua conta'), findsOneWidget);
          expect(find.text(NetworkException.defaultMessage), findsOneWidget);
          expect(fakes.session.hasStoredSession, isTrue);

          fakes.profile.error = null;
          await tester.tap(find.text('Tentar de novo'));
          await tester.pumpAndSettle();

          expect(routes, [AppRoutes.splash, AppRoutes.home]);
          expect(find.text('Olá, Maria'), findsOneWidget);
        },
      );

      testWidgets('deve ir ao login, sem aviso, pelo "Sair" da tela de erro (RM06)', (
        tester,
      ) async {
        fakes.profile.error = const NetworkException();
        final routes = await openWholeApp(tester, fakes);
        await tester.pumpAndSettle();

        await tester.signOutAndConfirm();
        await tester.pumpAndSettle();

        expect(routes, [AppRoutes.splash, AppRoutes.login]);
        expect(fakes.session.signOutCalls, 1);
        _expectNoReasonOnLogin();
      });

      testWidgets('deve voltar ao login com o aviso quando a sessão não renova mais (RM07)', (
        tester,
      ) async {
        // A renovação recusada pela API, como o refresh token vencido com o app fechado.
        fakes.session.secondFactorError = const UnauthorizedException();
        final routes = await openWholeApp(tester, fakes);

        await tester.pumpAndSettle();

        expect(routes, [AppRoutes.splash, AppRoutes.login]);
        expect(find.text(UnauthenticatedReason.sessionExpired.message), findsOneWidget);
      });

      testWidgets(
        'deve abrir a tela do código com a sessão pendente da segunda etapa, sem sair dela (RM18)',
        (tester) async {
          fakes.session.secondFactorPending = true;
          final routes = await openWholeApp(tester, fakes);

          await tester.pumpAndSettle();

          expect(routes, [AppRoutes.splash, AppRoutes.secondFactor]);
          expect(find.byType(SecondFactorView), findsOneWidget);
          expect(fakes.session.signOutCalls, 0);
          expect(fakes.session.hasStoredSession, isTrue);
          expect(fakes.profile.calls, 0, reason: 'A sessão pendente não chama o /users/me.');
          await tester.pump(SecondFactorViewModel.resendInterval);
        },
      );
    });

    group('login', () {
      testWidgets(
        'deve manter o e-mail depois da senha errada e entrar na tentativa seguinte (RM02)',
        (tester) async {
          fakes.auth.signInResult = const SignInWrongCredentials();
          final routes = await openWholeApp(tester, fakes);
          await tester.pumpAndSettle();
          await _signIn(tester, email: clientProfile.email, password: 'SenhaErrada123');
          expect(find.text(LoginViewModel.wrongCredentialsMessage), findsOneWidget);
          expect(_textOf(tester, _emailField), clientProfile.email);
          expect(_textOf(tester, _passwordField), isEmpty);

          fakes.auth.signInResult = const SignInSuccess();
          await tester.enterText(_passwordField, _password);
          await tester.tap(find.text('Entrar'));
          await tester.pumpAndSettle();

          expect(routes, [AppRoutes.splash, AppRoutes.login, AppRoutes.home]);
          expect(fakes.auth.signInCalls, hasLength(2));
          expect(find.text('Olá, Maria'), findsOneWidget);
        },
      );

      testWidgets('deve encerrar a sessão de um ADMIN e mostrar o aviso no login (RM01)', (
        tester,
      ) async {
        fakes.profile.result = adminProfile;
        final routes = await openWholeApp(tester, fakes);
        await tester.pumpAndSettle();

        await _signIn(tester, email: adminProfile.email);

        expect(routes, [AppRoutes.splash, AppRoutes.login]);
        expect(find.text(UnauthenticatedReason.roleNotAllowed.message), findsOneWidget);
        expect(fakes.session.signOutCalls, 1);
        expect(fakes.session.hasStoredSession, isFalse);
      });

      testWidgets(
        'deve ir para a tela do código depois do login com a verificação em duas etapas (RM18)',
        (tester) async {
          fakes.session.secondFactorPending = true;
          final routes = await openWholeApp(tester, fakes);
          await tester.pumpAndSettle();

          await _signIn(tester, email: clientProfile.email);

          expect(routes, [AppRoutes.splash, AppRoutes.login, AppRoutes.secondFactor]);
          expect(find.byType(SecondFactorView), findsOneWidget);
          expect(fakes.profile.calls, 0);
          expect(fakes.session.signOutCalls, 0);
          await tester.pump(SecondFactorViewModel.resendInterval);
        },
      );
    });

    group('tela inicial', () {
      setUp(() => fakes = AuthFakes(signedIn: true));

      testWidgets(
        'deve voltar ao login com o aviso quando a sessão acaba, e entrar de novo (RM07)',
        (tester) async {
          final routes = await openWholeApp(tester, fakes);
          await tester.pumpAndSettle();

          // Como a sessão encerrada em outro aparelho, que cai na renovação seguinte.
          fakes.session.expire();
          await tester.pumpAndSettle();
          expect(find.byType(LoginView), findsOneWidget);
          expect(find.text(UnauthenticatedReason.sessionExpired.message), findsOneWidget);
          await _signIn(tester, email: clientProfile.email);

          expect(routes, [AppRoutes.splash, AppRoutes.home, AppRoutes.login, AppRoutes.home]);
          expect(find.text('Olá, Maria'), findsOneWidget);
        },
      );

      testWidgets(
        'deve ir ao login, sem aviso, pelo "Sair", e o "voltar" não volta à tela inicial (RM10)',
        (tester) async {
          final routes = await openWholeApp(tester, fakes);
          await tester.pumpAndSettle();

          await tester.signOutAndConfirm();
          await tester.pumpAndSettle();

          expect(routes, [AppRoutes.splash, AppRoutes.home, AppRoutes.login]);
          expect(fakes.session.signOutCalls, 1);
          _expectNoReasonOnLogin();
          await expectBackClosesTheApp(tester);
          expect(find.byType(HomeView), findsNothing);
        },
      );

      testWidgets('deve continuar na tela inicial, com o aviso, no "Sair" sem conexão (RM10)', (
        tester,
      ) async {
        fakes.session.signOutError = const NetworkException();
        final routes = await openWholeApp(tester, fakes);
        await tester.pumpAndSettle();

        await tester.signOutAndConfirm();
        await tester.pumpAndSettle();

        expect(routes, [AppRoutes.splash, AppRoutes.home]);
        expect(find.widgetWithText(SnackBar, NetworkException.defaultMessage), findsOneWidget);
        expect(find.text('Olá, Maria'), findsOneWidget);
        expect(fakes.session.hasStoredSession, isTrue);
      });
    });
  });
}

/// Preenche o login e toca no "Entrar", como o usuário, e espera os passos depois do login.
Future<void> _signIn(
  WidgetTester tester, {
  required String email,
  String password = _password,
}) async {
  await tester.enterText(_emailField, email);
  await tester.enterText(_passwordField, password);
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle();
}

String _textOf(WidgetTester tester, Finder field) => tester
    .widget<EditableText>(find.descendant(of: field, matching: find.byType(EditableText)))
    .controller
    .text;

/// O login aberto pela saída do próprio usuário: sem nenhum dos motivos de ter voltado.
void _expectNoReasonOnLogin() {
  expect(find.byType(LoginView), findsOneWidget);
  for (final reason in UnauthenticatedReason.values) {
    expect(find.text(reason.message), findsNothing, reason: reason.name);
  }
}
