import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/home/presentation/views/home_view.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_profile.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';
import '../../../../support/pump_app.dart';
import '../../../../support/sign_out.dart';

const _unverifiedEmail = 'E-mail não confirmado';
const _refreshFailed = 'Os dados não foram atualizados';

void main() {
  group('HomeView', () {
    late AuthFakes fakes;

    final verifiedProfile = clientProfileWith(emailVerifiedAt: DateTime.utc(2026, 10, 5, 12));

    setUp(() => fakes = AuthFakes(signedIn: true));

    /// Abre a tela inicial com o Client já dentro.
    Future<void> pumpView(WidgetTester tester, {ThemeMode themeMode = ThemeMode.light}) async {
      await tester.pumpApp(const HomeView(), overrides: fakes.overrides, themeMode: themeMode);
      await tester.pump();
    }

    /// Puxa a tela para baixo, como o usuário, e solta: a atualização começa.
    Future<void> pullToRefresh(WidgetTester tester) async {
      await tester.fling(find.byType(SingleChildScrollView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    AuthState authState(WidgetTester tester) => tester.container().read(authControllerProvider);

    testWidgets('deve mostrar o nome do app e o "Sair" na barra superior', (tester) async {
      await pumpView(tester);

      final appBar = find.byType(AppBar);
      expect(find.descendant(of: appBar, matching: find.text('ReportaAi Cm')), findsOneWidget);
      expect(find.descendant(of: appBar, matching: find.text('Sair')), findsOneWidget);
    });

    group('saudação', () {
      for (final (name, greeting) in [
        ('Maria da Silva', 'Olá, Maria'),
        ('Maria', 'Olá, Maria'),
        ('  Maria   da  Silva ', 'Olá, Maria'),
      ]) {
        testWidgets('deve mostrar "$greeting" para o nome "$name"', (tester) async {
          fakes.profile.result = clientProfileWith(name: name);

          await pumpView(tester);

          expect(find.text(greeting), findsOneWidget);
        });
      }

      testWidgets('deve ser o título da tela para o leitor de tela', (tester) async {
        final semantics = tester.ensureSemantics();

        await pumpView(tester);

        expect(
          tester.getSemantics(find.text('Olá, Maria')),
          isSemantics(label: 'Olá, Maria', isHeader: true),
        );
        semantics.dispose();
      });
    });

    group('Seus dados', () {
      testWidgets('deve mostrar todos os campos formatados', (tester) async {
        await pumpView(tester);

        expect(find.text('Seus dados'), findsOneWidget);
        for (final (label, value) in [
          ('Nome', 'Maria da Silva'),
          ('E-mail', 'maria.silva@exemplo.com'),
          ('CPF', '***.982.247-**'),
          ('Telefone', '(44) 99999-8888'),
          ('Data de nascimento', '20/05/1990'),
        ]) {
          expect(find.text(label), findsOneWidget, reason: label);
          expect(find.text(value), findsOneWidget, reason: label);
        }
        expect(find.text('No ReportaAi desde outubro de 2026'), findsOneWidget);
      });

      testWidgets('deve mostrar o telefone fixo', (tester) async {
        fakes.profile.result = clientProfileWith(phone: '4433334444');

        await pumpView(tester);

        expect(find.text('(44) 3333-4444'), findsOneWidget);
      });

      testWidgets('deve mostrar o selo com o e-mail não confirmado', (tester) async {
        await pumpView(tester);

        expect(find.text(_unverifiedEmail), findsOneWidget);
      });

      testWidgets('não deve mostrar o selo com o e-mail confirmado', (tester) async {
        fakes.profile.result = verifiedProfile;

        await pumpView(tester);

        expect(find.text(_unverifiedEmail), findsNothing);
      });

      testWidgets('deve ler o rótulo, o valor e o selo juntos no leitor de tela', (tester) async {
        final semantics = tester.ensureSemantics();

        await pumpView(tester);

        expect(
          tester.getSemantics(find.text('(44) 99999-8888')),
          isSemantics(label: 'Telefone\n(44) 99999-8888'),
        );
        expect(
          tester.getSemantics(find.text(_unverifiedEmail)),
          isSemantics(label: 'E-mail\nmaria.silva@exemplo.com\n$_unverifiedEmail'),
        );
        semantics.dispose();
      });

      testWidgets('não deve mostrar o CPF completo em nenhum lugar da tela (RM09)', (tester) async {
        final semantics = tester.ensureSemantics();

        await pumpView(tester);

        for (final cpf in ['52998224725', '529.982.247-25']) {
          expect(find.textContaining(cpf), findsNothing, reason: cpf);
          expect(find.bySemanticsLabel(RegExp(RegExp.escape(cpf))), findsNothing, reason: cpf);
        }
        semantics.dispose();
      });
    });

    testWidgets('deve avisar que os reportes chegam em breve, sem ação', (tester) async {
      await pumpView(tester);

      final card = find.ancestor(of: find.text('Reportes em breve'), matching: find.byType(Card));
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.bySubtype<ButtonStyleButton>()),
        findsNothing,
      );
    });

    group('puxar para atualizar', () {
      testWidgets('deve buscar o perfil de novo e mostrar os dados novos', (tester) async {
        await pumpView(tester);
        expect(find.text(_unverifiedEmail), findsOneWidget);
        fakes.profile.result = verifiedProfile;

        await pullToRefresh(tester);
        await tester.pumpAndSettle();

        expect(fakes.profile.calls, 2);
        expect(authState(tester), AuthAuthenticated(verifiedProfile));
        expect(find.text(_unverifiedEmail), findsNothing);
      });

      testWidgets('deve mostrar o carregando enquanto atualiza', (tester) async {
        await pumpView(tester);
        final profile = fakes.profile.pending = Completer<UserProfile>();

        await pullToRefresh(tester);

        expect(find.byType(RefreshProgressIndicator), findsOneWidget);
        expect(find.text('Olá, Maria'), findsOneWidget, reason: 'Os dados continuam na tela.');

        profile.complete(verifiedProfile);
        await tester.pumpAndSettle();

        expect(find.byType(RefreshProgressIndicator), findsNothing);
      });

      testWidgets('deve manter os dados e avisar quando a atualização falha', (tester) async {
        await pumpView(tester);
        fakes.profile.error = const NetworkException();

        await pullToRefresh(tester);
        await tester.pumpAndSettle();

        expect(find.text(_refreshFailed), findsOneWidget);
        expect(find.text(NetworkException.defaultMessage), findsOneWidget);
        expect(find.text('Olá, Maria'), findsOneWidget);
        expect(find.text('***.982.247-**'), findsOneWidget);
        expect(authState(tester), AuthAuthenticated(clientProfile));
      });

      testWidgets('deve tirar o aviso quando a atualização seguinte dá certo', (tester) async {
        await pumpView(tester);
        fakes.profile.error = const NetworkException();
        await pullToRefresh(tester);
        await tester.pumpAndSettle();
        fakes.profile.error = null;

        await pullToRefresh(tester);
        await tester.pumpAndSettle();

        expect(find.text(_refreshFailed), findsNothing);
      });

      testWidgets('deve anunciar o aviso da atualização que falhou', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpView(tester);
        fakes.profile.error = const NetworkException();

        await pullToRefresh(tester);
        await tester.pumpAndSettle();

        expect(tester.getSemantics(find.text(_refreshFailed)), isSemantics(isLiveRegion: true));
        semantics.dispose();
      });

      testWidgets('deve atualizar pela ação do leitor de tela na saudação', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpView(tester);
        fakes.profile.result = verifiedProfile;

        tester.semantics.customAction(find.semantics.byLabel('Olá, Maria'), HomeView.refreshAction);
        await tester.pumpAndSettle();

        expect(fakes.profile.calls, 2);
        expect(find.text(_unverifiedEmail), findsNothing);
        semantics.dispose();
      });
    });

    group('"Sair"', () {
      testWidgets('deve sair depois da confirmação, e os dados saem da tela (RM10)', (
        tester,
      ) async {
        await pumpView(tester);

        await tester.signOutAndConfirm();
        await tester.pumpAndSettle();

        expect(fakes.session.signOutCalls, 1);
        expect(authState(tester), const AuthUnauthenticated());
        expect(find.text(clientProfile.name), findsNothing);
      });

      testWidgets('deve avisar e continuar logado sem conexão (RM10)', (tester) async {
        fakes.session.signOutError = const NetworkException();
        await pumpView(tester);

        await tester.signOutAndConfirm();
        await tester.pumpAndSettle();

        expect(find.widgetWithText(SnackBar, NetworkException.defaultMessage), findsOneWidget);
        expect(authState(tester), AuthAuthenticated(clientProfile));
        expect(find.text('Olá, Maria'), findsOneWidget);
      });
    });

    testWidgets('deve aguentar a fonte em 200%, com o selo e o aviso', (tester) async {
      tester.usePhoneScreen(textScale: 2);
      await pumpView(tester);
      fakes.profile.error = const NetworkException();

      await pullToRefresh(tester);
      await tester.pumpAndSettle();

      expect(find.text(_refreshFailed), findsOneWidget);
      expect(find.text(_unverifiedEmail), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('deve passar nas verificações de acessibilidade (${themeMode.name})', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpView(tester, themeMode: themeMode);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        // Também com o aviso da atualização que falhou, em cima dos dados.
        fakes.profile.error = const NetworkException();
        await pullToRefresh(tester);
        await tester.pumpAndSettle();

        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      });
    }
  });
}
