import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/routes.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/change_password_view_model.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/confirmation_password.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/second_factor_settings_view_model.dart';
import 'package:reportaai_cm/features/account/presentation/views/account_view.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/view_models/second_factor_view_model.dart';
import 'package:reportaai_cm/features/auth/presentation/views/login_view.dart';
import 'package:reportaai_cm/features/auth/presentation/views/second_factor_view.dart';
import 'package:reportaai_cm/features/home/presentation/views/home_view.dart';
import 'package:reportaai_cm/features/profile/domain/models/profile_changes.dart';

import '../support/app_flow.dart';
import '../support/auth_fakes.dart';
import '../support/fake_profile_repository.dart';
import '../support/fake_sessions_repository.dart';

const _password = 'senha-forte-1';
const _newPassword = 'senha-nova-2';

final Finder _currentPasswordField = find.widgetWithText(TextFormField, 'Senha atual');

/// Os fluxos do épico "Minha conta" de ponta a ponta, com o app inteiro: as rotas, as telas e o
/// `AuthController` de verdade, e só a sessão e os repositórios trocados pelos fakes. Os detalhes
/// de cada tela ficam nos testes dela.
void main() {
  group('Fluxo da conta', () {
    late AuthFakes fakes;

    setUp(() => fakes = AuthFakes(signedIn: true));

    /// Abre o app com o Client dentro e entra na "Minha conta" pela tela inicial.
    Future<List<String>> openAccount(WidgetTester tester) async {
      final routes = await openWholeApp(tester, fakes);
      await tester.pumpAndSettle();
      await _tapAndSettle(tester, find.byTooltip('Minha conta'));
      expect(find.byType(AccountView), findsOneWidget);
      return routes;
    }

    testWidgets('deve editar os dados e mostrá-los na tela inicial sem recarregar', (tester) async {
      final routes = await openAccount(tester);

      await _tapAndSettle(tester, find.text('Editar dados'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Nome completo'), 'Ana Souza');
      await tester.pump();
      await _tapAndSettle(tester, find.widgetWithText(FilledButton, 'Salvar'));

      expect(fakes.profile.updateCalls, [const ProfileChanges(name: 'Ana Souza')]);
      expect(find.byType(AccountView), findsOneWidget);
      expect(find.text('Ana Souza'), findsOneWidget);

      await _tapAndSettle(tester, find.byType(BackButton));

      expect(find.byType(HomeView), findsOneWidget);
      expect(find.text('Olá, Ana'), findsOneWidget);
      expect(fakes.profile.calls, 1, reason: 'Só a busca da abertura: o perfil veio do PATCH.');
      expect(routes, [
        AppRoutes.splash,
        AppRoutes.home,
        AppRoutes.account,
        AppRoutes.accountDetails,
        AppRoutes.account,
        AppRoutes.home,
      ]);
    });

    testWidgets('deve trocar a senha com a senha atual errada e depois a certa, sem sair da conta '
        '(RM15 e RM16)', (tester) async {
      fakes.profile.changePasswordError = const BusinessRuleException(
        message: 'Senha incorreta.',
        field: 'currentPassword',
      );
      await openAccount(tester);
      await _tapAndSettle(tester, find.text('Trocar senha'));
      expect(find.textContaining('os outros aparelhos saem da conta'), findsOneWidget);

      await _fillInPasswordChange(tester, currentPassword: 'errada-1');
      await _tapAndSettle(tester, find.widgetWithText(FilledButton, 'Trocar senha'));

      expect(find.text(ConfirmationPasswordMessages.incorrect), findsOneWidget);
      expect(find.byType(LoginView), findsNothing, reason: 'A senha errada não leva ao login.');

      fakes.profile.changePasswordError = null;
      await tester.enterText(_currentPasswordField, _password);
      await _tapAndSettle(tester, find.widgetWithText(FilledButton, 'Trocar senha'));

      expect(fakes.profile.changePasswordCalls, [
        (currentPassword: 'errada-1', newPassword: _newPassword),
        (currentPassword: _password, newPassword: _newPassword),
      ]);
      expect(find.byType(AccountView), findsOneWidget);
      expect(find.text(ChangePasswordViewModel.changedMessage), findsOneWidget);
      expect(fakes.session.hasStoredSession, isTrue);
    });

    testWidgets('deve encerrar outra sessão e manter a deste aparelho (RM19)', (tester) async {
      await openAccount(tester);
      await _tapAndSettle(tester, find.text('Sessões abertas'));
      expect(find.text('Este aparelho'), findsOneWidget);

      await _tapAndSettle(
        tester,
        find.descendant(
          of: find.ancestor(of: find.text('Navegador'), matching: find.byType(Card)),
          matching: find.text('Encerrar'),
        ),
      );
      await _tapAndSettle(
        tester,
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Encerrar')),
      );

      expect(fakes.sessions.revokeCalls, [browserSession.id]);
      expect(find.text('Navegador'), findsNothing);
      expect(find.text('Este aparelho'), findsOneWidget);
    });

    testWidgets(
      'deve ativar a verificação em duas etapas e pedir o código no login seguinte (RM18)',
      (tester) async {
        fakes.profile.result = clientProfileWith(emailVerifiedAt: emailVerifiedAt);
        final routes = await openAccount(tester);

        await _tapAndSettle(tester, find.text('Verificação em duas etapas'));
        await _tapAndSettle(tester, find.byType(SwitchListTile));
        await tester.enterText(_currentPasswordField, _password);
        await _tapAndSettle(tester, find.widgetWithText(FilledButton, 'Ativar a verificação'));

        expect(find.text(SecondFactorSettingsViewModel.enabledMessage), findsOneWidget);
        expect(find.text('Ativada'), findsOneWidget);
        // O aviso sai sozinho e deixa o "Sair" à vista.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // Sai e entra de novo: o login abre uma sessão pendente da segunda etapa.
        await _tapAndSettle(tester, find.text('Sair'));
        await _tapAndSettle(
          tester,
          find.descendant(of: find.byType(AlertDialog), matching: find.text('Sair')),
        );
        expect(find.byType(LoginView), findsOneWidget);
        fakes.session.secondFactorPending = true;
        await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), clientProfile.email);
        await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), _password);
        await _tapAndSettle(tester, find.text('Entrar'));

        expect(find.byType(SecondFactorView), findsOneWidget);
        // A sessão pendente não abre nenhuma outra tela.
        appRouter(tester).go(AppRoutes.account);
        await tester.pumpAndSettle();
        expect(find.byType(SecondFactorView), findsOneWidget);

        await tester.enterText(find.widgetWithText(TextFormField, 'Código'), '042137');
        await _tapAndSettle(tester, find.widgetWithText(FilledButton, 'Confirmar'));

        expect(fakes.auth.verifyLoginCodeCalls, ['042137']);
        expect(find.byType(HomeView), findsOneWidget);
        expect(routes.sublist(routes.length - 3), [
          AppRoutes.login,
          AppRoutes.secondFactor,
          AppRoutes.home,
        ]);
        await expectBackClosesTheApp(tester);
        await tester.pump(SecondFactorViewModel.resendInterval);
      },
    );

    testWidgets('deve sair da tela do código e voltar ao login (RM18)', (tester) async {
      fakes.session.secondFactorPending = true;
      await openWholeApp(tester, fakes);
      await tester.pumpAndSettle();
      expect(find.byType(SecondFactorView), findsOneWidget);

      await _tapAndSettle(tester, find.text('Sair'));
      await _tapAndSettle(
        tester,
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Sair')),
      );

      expect(find.byType(LoginView), findsOneWidget);
      expect(fakes.session.hasStoredSession, isFalse);
    });

    testWidgets('deve excluir a conta e voltar ao login com o aviso (RM17)', (tester) async {
      final routes = await openAccount(tester);

      await _tapAndSettle(tester, find.text('Excluir conta'));
      await tester.enterText(_currentPasswordField, _password);
      await _tapAndSettle(tester, find.byType(CheckboxListTile));
      await _tapAndSettle(tester, find.widgetWithText(FilledButton, 'Excluir minha conta'));

      expect(fakes.profile.deleteAccountCalls, [_password]);
      expect(find.byType(LoginView), findsOneWidget);
      expect(find.text(UnauthenticatedReason.accountDeleted.message), findsOneWidget);
      expect(find.text(UnauthenticatedReason.sessionExpired.message), findsNothing);
      expect(fakes.session.hasStoredSession, isFalse);
      expect(routes.last, AppRoutes.login);
      // O redirect trocou a pilha: o "voltar" não volta às telas da conta.
      await expectBackClosesTheApp(tester);
    });
  });
}

/// Preenche a troca de senha, com a senha nova nos dois campos.
Future<void> _fillInPasswordChange(WidgetTester tester, {required String currentPassword}) async {
  await tester.enterText(_currentPasswordField, currentPassword);
  await tester.enterText(find.widgetWithText(TextFormField, 'Senha nova'), _newPassword);
  await tester.enterText(find.widgetWithText(TextFormField, 'Repita a senha nova'), _newPassword);
}

/// Toca no [target], rolando a tela até ele, e espera a tela parar de mudar.
Future<void> _tapAndSettle(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}
