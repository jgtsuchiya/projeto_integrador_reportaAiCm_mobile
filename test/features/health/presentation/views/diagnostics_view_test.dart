import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/health/domain/models/health_status.dart';
import 'package:reportaai_cm/features/health/health_providers.dart';
import 'package:reportaai_cm/features/health/presentation/views/diagnostics_view.dart';

import '../../../../support/fake_health_repository.dart';
import '../../../../support/pump_app.dart';

void main() {
  group('DiagnosticsView', () {
    late FakeHealthRepository repository;

    setUp(() => repository = FakeHealthRepository());

    Future<void> pumpView(WidgetTester tester) async {
      await tester.pumpApp(
        const DiagnosticsView(),
        overrides: [healthRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pump();
    }

    testWidgets('deve mostrar o endereço da API usado pelo app', (tester) async {
      await pumpView(tester);

      expect(find.text('http://localhost:3000/api'), findsOneWidget);
    });

    testWidgets('deve mostrar o carregando enquanto confere a API', (tester) async {
      repository.pending = Completer<HealthStatus>();

      await pumpView(tester);

      expect(find.text('Conferindo a API...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repository.pending!.complete(okHealthStatus);
      await tester.pump();

      expect(find.text('ok'), findsOneWidget);
    });

    testWidgets('deve mostrar "ok" e o horário da resposta, no fuso do aparelho', (tester) async {
      await pumpView(tester);

      final localTime = okHealthStatus.checkedAt.toLocal();
      final hour = localTime.hour.toString().padLeft(2, '0');
      final minute = localTime.minute.toString().padLeft(2, '0');

      expect(find.text('ok'), findsOneWidget);
      expect(find.textContaining('A API respondeu em 20/10/2026 $hour:$minute'), findsOneWidget);
      expect(find.text('Conferir de novo'), findsOneWidget);
    });

    testWidgets('deve mostrar a mensagem clara com a API desligada', (tester) async {
      repository.error = const NetworkException();

      await pumpView(tester);

      expect(find.text('A API não respondeu'), findsOneWidget);
      expect(find.text(NetworkException.defaultMessage), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });

    testWidgets('deve conferir de novo no "Tentar de novo"', (tester) async {
      repository.error = const ServerException(statusCode: 500);
      await pumpView(tester);
      repository.error = null;

      await tester.tap(find.text('Tentar de novo'));
      await tester.pump();
      await tester.pump();

      expect(find.text('ok'), findsOneWidget);
      expect(repository.calls, 2);
    });

    testWidgets('deve mostrar o carregando ao conferir de novo', (tester) async {
      await pumpView(tester);
      repository.pending = Completer<HealthStatus>();

      await tester.tap(find.text('Conferir de novo'));
      await tester.pump();

      expect(find.text('Conferindo a API...'), findsOneWidget);

      repository.pending!.complete(okHealthStatus);
      await tester.pump();
    });

    for (final (state, setUpState) in [
      ('carregando', (FakeHealthRepository r) => r.pending = Completer<HealthStatus>()),
      ('erro', (FakeHealthRepository r) => r.error = const NetworkException()),
      ('sucesso', (FakeHealthRepository r) {}),
    ]) {
      testWidgets('deve aguentar a fonte em 200% no estado de $state', (tester) async {
        tester.usePhoneScreen(textScale: 2);
        setUpState(repository);

        await pumpView(tester);

        expect(tester.takeException(), isNull);
        repository.pending?.complete(okHealthStatus);
      });
    }
  });
}
