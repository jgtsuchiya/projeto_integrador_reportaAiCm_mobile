import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/location/location_service.dart';
import 'package:reportaai_cm/core/media/image_compressor.dart';
import 'package:reportaai_cm/core/media/photo_capture.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/new_report_view_model.dart';
import 'package:reportaai_cm/features/reports/presentation/view_models/report_photo_preparation.dart';
import 'package:reportaai_cm/features/reports/presentation/views/new_report_view.dart';

import '../../../../support/app_lifecycle.dart';
import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_location_service.dart';
import '../../../../support/fake_report_repository.dart';
import '../../../../support/pump_app.dart';
import '../../../../support/report_fakes.dart';
import '../../../../support/sample_images.dart';

final Finder _sendButton = find.widgetWithText(FilledButton, 'Enviar');
final Finder _descriptionField = find.widgetWithText(TextFormField, 'Descrição (opcional)');

void main() {
  group('NewReportView', () {
    late AuthFakes auth;
    late ReportFakes reports;

    setUp(() {
      auth = verifiedAuthFakes();
      reports = ReportFakes();
    });

    /// Abre a tela por cima de outra, como pela tela inicial, com o detalhe na rota de cada
    /// reporte. Termina com a câmera, a foto e a localização resolvidas pelos fakes.
    Future<GoRouter> pumpView(WidgetTester tester, {bool settle = true}) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text(screenBelow)),
          ),
          GoRoute(path: '/reportes/novo', builder: (context, state) => const NewReportView()),
          GoRoute(
            path: '/reportes/:id',
            builder: (context, state) => Scaffold(
              body: Text('Detalhe de ${state.pathParameters['id']}, a ${state.extra} m'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpRouter(router, overrides: [...auth.overrides, ...reports.overrides]);
      AuthFakes.startAuth(tester.container());
      await tester.pumpAndSettle();
      unawaited(router.push('/reportes/novo'));
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
        await tester.pump();
      }
      return router;
    }

    /// Rola até o [target], toca e espera a tela parar.
    Future<void> tapVisible(WidgetTester tester, Finder target) async {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    bool isEnabled(WidgetTester tester, Finder button) =>
        tester.widget<ButtonStyleButton>(button).onPressed != null;

    group('e-mail (RM20)', () {
      testWidgets('deve mostrar o aviso do e-mail no lugar do formulário, sem abrir a câmera', (
        tester,
      ) async {
        auth = AuthFakes(signedIn: true);

        await pumpView(tester);

        expect(find.text('Confirme o seu e-mail'), findsOneWidget);
        expect(find.text('Reenviar e-mail'), findsOneWidget);
        expect(_sendButton, findsNothing);
        expect(reports.camera.calls, 0);
      });
    });

    group('foto', () {
      testWidgets('deve mostrar a foto tratada, com a descrição para o leitor de tela', (
        tester,
      ) async {
        await pumpView(tester);

        expect(find.bySemanticsLabel('Foto do buraco que você tirou'), findsOneWidget);
        expect(find.text('Tirar outra'), findsOneWidget);
        expect(reports.camera.calls, 1);
      });

      testWidgets('deve mostrar a câmera aberta e o tratamento da foto', (tester) async {
        reports.camera.pending = Completer();
        reports.compressor.pending = Completer();
        await pumpView(tester, settle: false);

        expect(find.text('A câmera está aberta.'), findsOneWidget);

        reports.camera.pending!.complete();
        await tester.pump();
        await tester.pump();

        expect(find.text('Preparando a foto…'), findsOneWidget);
        expect(isEnabled(tester, _sendButton), isFalse);

        reports.compressor.pending!.complete();
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Foto do buraco que você tirou'), findsOneWidget);
      });

      testWidgets('deve oferecer a câmera de novo quando o cidadão cancela', (tester) async {
        reports.camera.photo = null;
        await pumpView(tester);

        expect(find.text('Tirar a foto'), findsOneWidget);
        expect(isEnabled(tester, _sendButton), isFalse);

        reports.camera.photo = sampleJpegWithExif;
        await tapVisible(tester, find.text('Tirar a foto'));

        expect(reports.camera.calls, 2);
        expect(find.bySemanticsLabel('Foto do buraco que você tirou'), findsOneWidget);
      });

      testWidgets('deve avisar a câmera que não abre, com o "Tirar outra"', (tester) async {
        reports.camera.error = const CameraUnavailableException();

        await pumpView(tester);

        expect(find.text(NewReportViewModel.cameraUnavailableMessage), findsOneWidget);
        expect(find.text('Tirar outra'), findsOneWidget);
      });

      testWidgets('deve pedir outra foto quando o tratamento falha', (tester) async {
        reports.compressor.error = const ImageCompressionException();

        await pumpView(tester);

        expect(find.text(photoNotUsableMessage), findsOneWidget);
      });
    });

    group('localização (RM21)', () {
      testWidgets('deve mostrar a precisão da localização encontrada', (tester) async {
        await pumpView(tester);

        expect(find.text('Localização encontrada'), findsOneWidget);
        expect(find.text('Precisão de 8 m'), findsOneWidget);
        expect(isEnabled(tester, _sendButton), isTrue);
      });

      testWidgets('deve mostrar a busca da localização', (tester) async {
        reports.location.positionPending = Completer();
        await pumpView(tester, settle: false);
        await tester.pump();

        expect(find.text('Buscando a sua localização'), findsOneWidget);

        reports.location.positionPending!.complete();
        await tester.pumpAndSettle();
      });

      testWidgets('deve bloquear o envio com a localização imprecisa e liberar no "Atualizar '
          'localização"', (tester) async {
        reports.location.position = campoMouraoPositionWith(accuracyMeters: 80);
        await pumpView(tester);

        expect(find.text('A localização está imprecisa'), findsOneWidget);
        expect(find.textContaining('Precisão de 80 m'), findsOneWidget);
        expect(isEnabled(tester, _sendButton), isFalse);

        reports.location.position = campoMouraoPosition;
        await tapVisible(tester, find.text('Atualizar localização'));

        expect(find.text('Localização encontrada'), findsOneWidget);
        expect(isEnabled(tester, _sendButton), isTrue);
      });

      testWidgets('deve bloquear o envio com a localização falsa', (tester) async {
        reports.location.position = campoMouraoPositionWith(isMocked: true);

        await pumpView(tester);

        expect(find.text('A localização parece falsa'), findsOneWidget);
        expect(isEnabled(tester, _sendButton), isFalse);
      });

      testWidgets('deve explicar antes de pedir a permissão', (tester) async {
        reports.location.permission = LocationPermissionStatus.denied;
        await pumpView(tester);

        expect(find.text('Precisamos da sua localização'), findsOneWidget);
        expect(reports.location.requestPermissionCalls, 0);

        reports.location.permissionAfterRequest = LocationPermissionStatus.denied;
        await tapVisible(tester, find.text('Permitir a localização'));

        expect(find.text('Sem a permissão da localização'), findsOneWidget);

        reports.location.permissionAfterRequest = LocationPermissionStatus.granted;
        await tapVisible(tester, find.text('Permitir a localização'));

        expect(find.text('Localização encontrada'), findsOneWidget);
      });

      testWidgets('deve abrir as configurações com a permissão negada para sempre e ler de novo '
          'na volta', (tester) async {
        reports.location.permission = LocationPermissionStatus.deniedForever;
        await pumpView(tester);

        await tapVisible(tester, find.text('Abrir as configurações'));
        reports.location.permission = LocationPermissionStatus.granted;
        tester.leaveAndComeBack();
        await tester.pumpAndSettle();

        expect(reports.location.openAppSettingsCalls, 1);
        expect(find.text('Localização encontrada'), findsOneWidget);
      });

      testWidgets('deve oferecer o "Ativar a localização" com o GPS desligado', (tester) async {
        reports.location.serviceEnabled = false;
        await pumpView(tester);

        await tapVisible(tester, find.text('Ativar a localização'));

        expect(reports.location.openLocationSettingsCalls, 1);
      });

      testWidgets('deve oferecer o "Atualizar localização" quando o aparelho não acha a posição', (
        tester,
      ) async {
        reports.location.positionError = const LocationTimeoutException();

        await pumpView(tester);

        expect(find.text('Não encontramos a sua localização'), findsOneWidget);
        expect(find.text('Atualizar localização'), findsOneWidget);
      });
    });

    group('reporte repetido (RM23)', () {
      setUp(() => reports.repository.nearby = [othersReport()]);

      testWidgets('deve avisar o reporte a 12 m, com a miniatura, e bloquear o envio', (
        tester,
      ) async {
        await pumpView(tester);

        expect(find.text('Já existe um reporte a 12 m daqui'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('Foto do reporte já aberto')), findsOneWidget);
        expect(isEnabled(tester, _sendButton), isFalse);
      });

      testWidgets('deve abrir o reporte existente no "Ver o reporte", com a distância', (
        tester,
      ) async {
        await pumpView(tester);

        await tapVisible(tester, find.text('Ver o reporte'));

        expect(find.text('Detalhe de reporte-de-outro, a 12 m'), findsOneWidget);
      });

      testWidgets('deve seguir com o reporte novo no "É outro buraco"', (tester) async {
        await pumpView(tester);

        await tapVisible(tester, find.text('É outro buraco'));

        expect(find.textContaining('Já existe um reporte'), findsNothing);
        expect(isEnabled(tester, _sendButton), isTrue);
      });
    });

    group('envio', () {
      Future<void> send(WidgetTester tester) => tapVisible(tester, _sendButton);

      testWidgets('deve ir para o detalhe com o aviso das 10 confirmações, no lugar da tela', (
        tester,
      ) async {
        final router = await pumpView(tester);
        await tester.enterText(_descriptionField, 'Perto do semáforo');

        await send(tester);

        expect(reports.repository.createCalls.single.draft.description, 'Perto do semáforo');
        expect(find.text('Detalhe de novo-1, a null m'), findsOneWidget);
        expect(
          find.text('Reporte enviado. Agora ele precisa de 10 confirmações de outros cidadãos.'),
          findsOneWidget,
        );

        router.pop();
        await tester.pumpAndSettle();

        expect(
          find.text(screenBelow),
          findsOneWidget,
          reason: 'O "voltar" não volta ao formulário.',
        );
      });

      testWidgets('deve mostrar o carregando e não enviar duas vezes', (tester) async {
        await pumpView(tester);
        reports.repository.createPending = Completer();

        await tester.ensureVisible(_sendButton);
        await tester.tap(_sendButton);
        await tester.pump();
        await tester.tap(find.bySemanticsLabel(RegExp('Carregando')), warnIfMissed: false);
        await tester.pump();

        expect(reports.repository.createCalls, hasLength(1));

        reports.repository.createPending!.complete();
        await tester.pumpAndSettle();
      });

      testWidgets('deve manter os dados sem conexão e repetir com a mesma chave no "Tentar de '
          'novo" (RM24)', (tester) async {
        await pumpView(tester);
        await tester.enterText(_descriptionField, 'Buraco fundo');
        reports.repository.createError = const NetworkException(isTimeout: true);

        await send(tester);

        expect(find.text(NewReportViewModel.sendFailedMessage), findsOneWidget);
        expect(find.text('Buraco fundo'), findsOneWidget);
        expect(find.bySemanticsLabel('Foto do buraco que você tirou'), findsOneWidget);

        reports.repository.createError = null;
        await tapVisible(tester, find.widgetWithText(FilledButton, 'Tentar de novo'));

        final keys = reports.repository.createCalls.map((call) => call.idempotencyKey);
        expect(keys, hasLength(2));
        expect(keys.toSet(), hasLength(1));
        expect(find.text('Detalhe de novo-1, a null m'), findsOneWidget);
      });

      testWidgets('deve pedir outra foto no 400 da foto e no 413', (tester) async {
        await pumpView(tester);
        reports.repository.createError = const ServerException(statusCode: 413);

        await send(tester);

        expect(find.text(photoNotUsableMessage), findsOneWidget);
        expect(isEnabled(tester, _sendButton), isFalse);
      });

      testWidgets('deve mostrar o 400 da descrição embaixo do campo', (tester) async {
        await pumpView(tester);
        reports.repository.createError = const ValidationException(
          fieldErrors: [FieldError(field: 'description', message: 'Descrição inválida.')],
        );

        await send(tester);

        expect(
          find.descendant(of: _descriptionField, matching: find.text('Descrição inválida.')),
          findsOneWidget,
        );
      });

      testWidgets('deve mostrar a message do 422 da API', (tester) async {
        await pumpView(tester);
        reports.repository.createError = const BusinessRuleException(
          message: 'Este lugar fica fora de Campo Mourão.',
        );

        await send(tester);

        expect(find.text('Este lugar fica fora de Campo Mourão.'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Enviar'), findsOneWidget);
      });

      testWidgets('deve anunciar o aviso do envio para o leitor de tela', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpView(tester);
        reports.repository.createError = const NetworkException();

        await send(tester);

        expect(
          tester.getSemantics(find.text(NewReportViewModel.sendFailedMessage)),
          isSemantics(isLiveRegion: true),
        );
        semantics.dispose();
      });
    });

    group('voltar', () {
      testWidgets('deve perguntar antes de descartar a foto tirada', (tester) async {
        await pumpView(tester);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.text('Descartar o reporte?'), findsOneWidget);

        await tester.tap(find.text('Continuar o reporte'));
        await tester.pumpAndSettle();

        expect(find.byType(NewReportView), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Descartar'));
        await tester.pumpAndSettle();

        expect(find.text(screenBelow), findsOneWidget);
      });

      testWidgets('deve voltar direto sem foto', (tester) async {
        reports.camera.photo = null;
        await pumpView(tester);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.text(screenBelow), findsOneWidget);
      });
    });

    testWidgets('deve aguentar a fonte em 200%, com o aviso do reporte repetido', (tester) async {
      tester.usePhoneScreen(textScale: 2);
      reports.repository.nearby = [othersReport()];

      await pumpView(tester);

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(_sendButton);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('deve passar nas verificações de acessibilidade', (tester) async {
      tester.view
        ..physicalSize = const Size(800, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      await tester.pumpApp(
        const NewReportView(),
        overrides: [...auth.overrides, ...reports.overrides],
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  });
}
