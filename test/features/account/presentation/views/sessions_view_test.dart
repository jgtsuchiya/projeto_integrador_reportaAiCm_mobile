import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/sessions_view_model.dart';
import 'package:reportaai_cm/features/account/presentation/views/sessions_view.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_sessions_repository.dart';
import '../../../../support/pump_app.dart';

final Finder _revokeOthers = find.text('Encerrar todas as outras');

/// O "Encerrar" do diálogo de confirmação, que não se confunde com o da lista.
final Finder _confirmRevoke = find.descendant(
  of: find.byType(AlertDialog),
  matching: find.text('Encerrar'),
);

void main() {
  group('SessionsView', () {
    late AuthFakes fakes;

    setUp(() => fakes = AuthFakes(signedIn: true));

    Future<void> pumpView(WidgetTester tester) async {
      await tester.pumpApp(const SessionsView(), overrides: fakes.overrides);
      await tester.pumpAndSettle();
    }

    /// O "Encerrar" do cartão da sessão com o [label].
    Finder revokeOf(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Card)),
      matching: find.text('Encerrar'),
    );

    testWidgets('deve listar as sessões, com a deste aparelho primeiro e sem o "Encerrar"', (
      tester,
    ) async {
      await pumpView(tester);

      expect(find.text('App ReportaAi (Android)'), findsOneWidget);
      expect(find.text('Navegador'), findsOneWidget);
      expect(find.text('Aparelho desconhecido'), findsOneWidget);
      expect(find.text('Este aparelho'), findsOneWidget);
      expect(find.text('IP 203.0.113.10'), findsOneWidget);
      expect(find.text('IP 198.51.100.7'), findsOneWidget);
      expect(find.textContaining('Entrou em'), findsNWidgets(3));
      // A sessão deste aparelho vem primeiro (RM19).
      expect(
        tester.getTopLeft(find.text('App ReportaAi (Android)')).dy,
        lessThan(tester.getTopLeft(find.text('Navegador')).dy),
      );
      expect(revokeOf('App ReportaAi (Android)'), findsNothing);
      expect(revokeOf('Navegador'), findsOneWidget);
      expect(_revokeOthers, findsOneWidget);
    });

    testWidgets('deve mostrar o carregando e, sem conexão, o erro com o "Tentar de novo"', (
      tester,
    ) async {
      final pending = fakes.sessions.listPending = Completer<void>();
      fakes.sessions.listError = const NetworkException();
      await tester.pumpApp(const SessionsView(), overrides: fakes.overrides);
      await tester.pump();

      expect(find.text('Carregando as sessões'), findsOneWidget);

      pending.complete();
      await tester.pumpAndSettle();

      expect(find.text(NetworkException.defaultMessage), findsOneWidget);

      fakes.sessions
        ..listPending = null
        ..listError = null;
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.text('Navegador'), findsOneWidget);
    });

    testWidgets('deve encerrar uma sessão depois da confirmação', (tester) async {
      await pumpView(tester);

      await tester.tap(revokeOf('Navegador'));
      await tester.pumpAndSettle();
      expect(find.text('Encerrar esta sessão?'), findsOneWidget);

      await tester.tap(_confirmRevoke);
      await tester.pumpAndSettle();

      expect(fakes.sessions.revokeCalls, [browserSession.id]);
      expect(find.text('Navegador'), findsNothing);
      expect(find.text(SessionsViewModel.revokedMessage), findsOneWidget);
    });

    testWidgets('não deve encerrar sem a confirmação', (tester) async {
      await pumpView(tester);

      await tester.tap(revokeOf('Navegador'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(fakes.sessions.revokeCalls, isEmpty);
      expect(find.text('Navegador'), findsOneWidget);
    });

    testWidgets('deve tirar da lista, sem erro, a sessão que já tinha acabado (404)', (
      tester,
    ) async {
      fakes.sessions.revokeError = const NotFoundException();
      await pumpView(tester);

      await tester.tap(revokeOf('Aparelho desconhecido'));
      await tester.pumpAndSettle();
      await tester.tap(_confirmRevoke);
      await tester.pumpAndSettle();

      expect(find.text('Aparelho desconhecido'), findsNothing);
      expect(find.text(NotFoundException.defaultMessage), findsNothing);
    });

    testWidgets('deve manter a sessão e mostrar o erro sem conexão', (tester) async {
      fakes.sessions.revokeError = const NetworkException();
      await pumpView(tester);

      await tester.tap(revokeOf('Navegador'));
      await tester.pumpAndSettle();
      await tester.tap(_confirmRevoke);
      await tester.pumpAndSettle();

      expect(find.text('Navegador'), findsOneWidget);
      expect(find.text(NetworkException.defaultMessage), findsOneWidget);
    });

    testWidgets('deve encerrar todas as outras depois da confirmação (RM19)', (tester) async {
      await pumpView(tester);

      await tester.tap(_revokeOthers);
      await tester.pumpAndSettle();
      expect(find.text('Encerrar as outras sessões?'), findsOneWidget);

      await tester.tap(_confirmRevoke);
      await tester.pumpAndSettle();

      expect(fakes.sessions.revokeOthersCalls, 1);
      expect(find.text('App ReportaAi (Android)'), findsOneWidget);
      expect(find.text('Navegador'), findsNothing);
      expect(_revokeOthers, findsNothing, reason: 'Sem outras sessões, o botão sai.');
      expect(find.text(SessionsViewModel.othersRevokedMessage), findsOneWidget);
    });

    testWidgets('deve atualizar a lista ao puxar para baixo e avisar quando falha', (tester) async {
      await pumpView(tester);
      fakes.sessions.sessions = [currentSession];

      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(fakes.sessions.listCalls, 2);
      expect(find.text('Navegador'), findsNothing);

      fakes.sessions.listError = const NetworkException();
      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(find.textContaining('A lista não foi atualizada.'), findsOneWidget);
      expect(find.text('App ReportaAi (Android)'), findsOneWidget);
    });

    testWidgets('deve aguentar a fonte em 200%', (tester) async {
      tester.usePhoneScreen(textScale: 2);
      await pumpView(tester);

      expect(tester.takeException(), isNull);
    });
  });
}
