import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/email_verification_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/widgets/email_verification_notice.dart';

import '../../../../support/app_lifecycle.dart';
import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';
import '../../../../support/pump_app.dart';

final Finder _title = find.text('Confirme o seu e-mail');
final Finder _resendButton = find.byType(FilledButton);

void main() {
  group('EmailVerificationNotice', () {
    late AuthFakes fakes;

    final verifiedProfile = clientProfileWith(emailVerifiedAt: DateTime.utc(2026, 10, 5, 12));

    setUp(() => fakes = AuthFakes(signedIn: true));

    /// O aviso sozinho, com o Client já dentro.
    Future<void> pumpNotice(WidgetTester tester, {ThemeMode themeMode = ThemeMode.light}) async {
      await tester.pumpApp(
        const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: EmailVerificationNotice(),
          ),
        ),
        overrides: fakes.overrides,
        themeMode: themeMode,
      );
      await tester.pump();
    }

    Future<void> leaveAndComeBack(WidgetTester tester) async {
      tester.leaveAndComeBack();
      await tester.pumpAndSettle();
    }

    VoidCallback? onResend(WidgetTester tester) =>
        tester.widget<FilledButton>(_resendButton).onPressed;

    testWidgets('deve mostrar o aviso, o e-mail e por que confirmar (RM14)', (tester) async {
      await pumpNotice(tester);

      expect(_title, findsOneWidget);
      expect(find.textContaining(clientProfile.email), findsOneWidget);
      expect(find.textContaining('abrir e validar reportes'), findsOneWidget);
      expect(find.text('Reenviar e-mail'), findsOneWidget);
    });

    testWidgets('não deve mostrar nada com o e-mail confirmado', (tester) async {
      fakes.profile.result = verifiedProfile;

      await pumpNotice(tester);

      expect(_title, findsNothing);
      expect(_resendButton, findsNothing);
    });

    testWidgets('não deve mostrar nada sem o Client dentro', (tester) async {
      fakes.session.hasStoredSession = false;

      await pumpNotice(tester);

      expect(_title, findsNothing);
    });

    group('"Reenviar e-mail"', () {
      testWidgets('deve reenviar, avisar e desativar o botão por 1 minuto (RM14)', (tester) async {
        await pumpNotice(tester);

        await tester.tap(_resendButton);
        await tester.pump();

        expect(fakes.profile.resendCalls, 1);
        expect(find.text(EmailVerificationController.sentMessage), findsOneWidget);
        expect(find.text('Reenviar e-mail em 60 s'), findsOneWidget);
        expect(onResend(tester), isNull);

        await tester.pump(const Duration(seconds: 59));
        expect(find.text('Reenviar e-mail em 1 s'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Reenviar e-mail'), findsOneWidget);
        expect(onResend(tester), isNotNull);
      });

      testWidgets('deve começar desativado logo depois do cadastro (RM14)', (tester) async {
        await pumpNotice(tester);

        tester
            .container()
            .read(emailVerificationControllerProvider.notifier)
            .markSent(clientProfile.email);
        await tester.pump();

        expect(find.text('Reenviar e-mail em 60 s'), findsOneWidget);
        expect(onResend(tester), isNull);
        await tester.pump(const Duration(minutes: 1));
      });

      testWidgets('não deve usar a espera do cadastro de outra conta', (tester) async {
        await pumpNotice(tester);

        tester
            .container()
            .read(emailVerificationControllerProvider.notifier)
            .markSent('outra@exemplo.com');
        await tester.pump();

        expect(find.text('Reenviar e-mail'), findsOneWidget);
        expect(onResend(tester), isNotNull);
        await tester.pump(const Duration(minutes: 1));
      });

      testWidgets('deve mostrar o "Enviando" durante o reenvio', (tester) async {
        final pending = fakes.profile.resendPending = Completer<void>();
        await pumpNotice(tester);

        await tester.tap(_resendButton);
        await tester.pump();

        expect(find.bySemanticsLabel(RegExp('Enviando')), findsOneWidget);
        expect(onResend(tester), isNull);

        pending.complete();
        await tester.pump();
        await tester.pump(const Duration(minutes: 1));
      });

      testWidgets('deve mostrar a message do 422 da API', (tester) async {
        const message = 'Um e-mail acabou de ser enviado. Aguarde um minuto para pedir outro.';
        fakes.profile.resendError = const BusinessRuleException(message: message);
        await pumpNotice(tester);

        await tester.tap(_resendButton);
        await tester.pumpAndSettle();

        expect(find.text(message), findsOneWidget);
        expect(onResend(tester), isNotNull);
      });

      testWidgets('deve anunciar o resultado do reenvio ao leitor de tela', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpNotice(tester);

        await tester.tap(_resendButton);
        await tester.pump();

        expect(
          tester.getSemantics(find.text(EmailVerificationController.sentMessage)),
          isSemantics(isLiveRegion: true),
        );
        semantics.dispose();
        await tester.pump(const Duration(minutes: 1));
      });
    });

    group('volta para o primeiro plano (RM14)', () {
      testWidgets('deve atualizar o perfil e sumir com o e-mail confirmado', (tester) async {
        await pumpNotice(tester);
        fakes.profile.result = verifiedProfile;

        await leaveAndComeBack(tester);

        expect(fakes.profile.calls, 2);
        expect(_title, findsNothing);
        expect(tester.container().read(authControllerProvider), AuthAuthenticated(verifiedProfile));
      });

      testWidgets('não deve mostrar erro quando a atualização falha', (tester) async {
        await pumpNotice(tester);
        fakes.profile.error = const NetworkException();

        await leaveAndComeBack(tester);

        expect(fakes.profile.calls, 2);
        expect(_title, findsOneWidget);
        expect(find.text(NetworkException.defaultMessage), findsNothing);
      });

      testWidgets('deve atualizar no máximo uma vez a cada 30 s', (tester) async {
        await pumpNotice(tester);

        await leaveAndComeBack(tester);
        await leaveAndComeBack(tester);

        expect(fakes.profile.calls, 2);

        await tester.pump(const Duration(seconds: 30));
        await leaveAndComeBack(tester);

        expect(fakes.profile.calls, 3);
        await tester.pump(const Duration(seconds: 30));
      });
    });

    testWidgets('deve aguentar a fonte em 200%, com o resultado do reenvio', (tester) async {
      tester.usePhoneScreen(textScale: 2);
      await pumpNotice(tester);

      await tester.ensureVisible(_resendButton);
      await tester.tap(_resendButton);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text(EmailVerificationController.sentMessage), findsOneWidget);
      await tester.pump(const Duration(minutes: 1));
    });

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('deve passar nas verificações de acessibilidade (${themeMode.name})', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpNotice(tester, themeMode: themeMode);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        // Também com o erro do reenvio.
        fakes.profile.resendError = const NetworkException();
        await tester.tap(_resendButton);
        await tester.pumpAndSettle();

        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      });
    }
  });
}
