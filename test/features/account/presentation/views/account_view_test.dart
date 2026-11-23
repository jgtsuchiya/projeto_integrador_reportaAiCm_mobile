import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/app/router.dart';
import 'package:reportaai_cm/app/routes.dart';
import 'package:reportaai_cm/features/account/presentation/views/account_view.dart';
import 'package:reportaai_cm/features/account/presentation/views/change_password_view.dart';
import 'package:reportaai_cm/features/account/presentation/views/delete_account_view.dart';
import 'package:reportaai_cm/features/account/presentation/views/edit_profile_view.dart';
import 'package:reportaai_cm/features/account/presentation/views/second_factor_settings_view.dart';
import 'package:reportaai_cm/features/account/presentation/views/sessions_view.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';
import '../../../../support/pump_app.dart';
import '../../../../support/sign_out.dart';

void main() {
  group('AccountView', () {
    late AuthFakes fakes;

    setUp(() => fakes = AuthFakes(signedIn: true));

    /// Abre o app inteiro com o Client dentro, já na "Minha conta", por cima da tela inicial.
    Future<GoRouter> openAccount(WidgetTester tester) async {
      await tester.pumpWholeApp(overrides: fakes.overrides);
      await tester.pumpAndSettle();
      final router = tester.container().read(routerProvider);
      await tester.tap(find.byTooltip('Minha conta'));
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('deve abrir pela tela inicial e voltar para ela', (tester) async {
      final router = await openAccount(tester);

      expect(find.byType(AccountView), findsOneWidget);
      expect(router.canPop(), isTrue);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.home);
    });

    testWidgets('deve mostrar os dados, com o CPF mascarado (RM09)', (tester) async {
      await openAccount(tester);

      expect(find.text('Maria da Silva'), findsOneWidget);
      expect(find.text('maria.silva@exemplo.com'), findsOneWidget);
      expect(find.text('***.982.247-**'), findsOneWidget);
      expect(find.text(clientProfile.cpf!), findsNothing);
      expect(find.text('(44) 99999-8888'), findsOneWidget);
      expect(find.text('20/05/1990'), findsOneWidget);
    });

    testWidgets('deve dizer se a verificação em duas etapas está ativa', (tester) async {
      await openAccount(tester);
      expect(find.text('Desativada'), findsOneWidget);

      tester
          .container()
          .read(authControllerProvider.notifier)
          .replaceProfile(clientProfileWith(mfaEnabled: true));
      await tester.pump();

      expect(find.text('Ativada'), findsOneWidget);
    });

    for (final (entry, screen) in [
      ('Editar dados', EditProfileView),
      ('Trocar senha', ChangePasswordView),
      ('Sessões abertas', SessionsView),
      ('Verificação em duas etapas', SecondFactorSettingsView),
      ('Excluir conta', DeleteAccountView),
    ]) {
      testWidgets('deve abrir a $screen pelo "$entry" e voltar', (tester) async {
        await openAccount(tester);

        await tester.ensureVisible(find.text(entry));
        await tester.tap(find.text(entry));
        await tester.pumpAndSettle();

        expect(find.byType(screen), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byType(AccountView), findsOneWidget);
      });
    }

    testWidgets('deve sair pelo "Sair", com a confirmação', (tester) async {
      await openAccount(tester);
      await tester.ensureVisible(find.text('Sair'));

      await tester.signOutAndConfirm();
      await tester.pumpAndSettle();

      expect(tester.container().read(authControllerProvider), const AuthUnauthenticated());
      expect(find.text('Entrar no ReportaAi Cm'), findsOneWidget);
    });

    testWidgets('não deve mostrar nada sem o Client dentro', (tester) async {
      await tester.pumpApp(const AccountView(), overrides: AuthFakes().overrides);
      await tester.pump();

      expect(find.text('Editar dados'), findsNothing);
    });

    testWidgets('deve aguentar a fonte em 200%', (tester) async {
      tester.usePhoneScreen(textScale: 2);
      await openAccount(tester);

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Sair'));
      expect(tester.takeException(), isNull);
    });
  });
}
