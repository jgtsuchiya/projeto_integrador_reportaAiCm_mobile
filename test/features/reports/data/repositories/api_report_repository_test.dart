import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/reports/data/repositories/api_report_repository.dart';
import 'package:reportaai_cm/features/reports/domain/models/geo_location.dart';
import 'package:reportaai_cm/features/reports/domain/models/prepared_photo.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_draft.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';
import 'package:reportaai_cm/features/reports/domain/models/vote_type.dart';

import '../../../../support/fake_http_adapter.dart';
import '../../../../support/fake_report_repository.dart';
import '../../../../support/sample_images.dart';

const _idempotencyKey = '3b241101-e2bb-4255-8caf-4136c566a962';

/// O corpo enviado, como a API recebe.
Map<String, Object?> _sentBody(RequestOptions request) => switch (request.data) {
  final String text => jsonDecode(text) as Map<String, Object?>,
  final Map<String, Object?> json => json,
  final other => throw StateError('Corpo inesperado: $other'),
};

void main() {
  group('ApiReportRepository', () {
    late FakeHttpAdapter adapter;
    late ApiReportRepository sut;

    final photo = PreparedPhoto.create(photo: samplePhotoJpeg, thumbnail: sampleThumbnailJpeg);
    final draft = ReportDraft(
      location: const GeoLocation(latitude: -24.045812, longitude: -52.378901, accuracyMeters: 8.5),
      photo: photo,
      description: 'Buraco grande na faixa da direita, perto do semáforo.',
    );

    setUp(() {
      adapter = FakeHttpAdapter();
      sut = ApiReportRepository(fakeDio(adapter));
    });

    group('create', () {
      test('deve enviar o POST /api/reports com a Idempotency-Key e devolver o reporte', () async {
        adapter.reply(201, body: reportJson);

        final report = await sut.create(draft, idempotencyKey: _idempotencyKey);

        final request = adapter.requests.single;
        expect(report, sampleReport);
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/reports');
        expect(request.headers['Idempotency-Key'], _idempotencyKey);
      });

      test('deve mandar a foto e a miniatura em base64 válido, que voltam aos bytes', () async {
        adapter.reply(201, body: reportJson);

        await sut.create(draft, idempotencyKey: _idempotencyKey);

        final body = _sentBody(adapter.requests.single);
        final sentPhoto = body['photo']! as Map<String, Object?>;
        expect(base64Decode(sentPhoto['content']! as String), samplePhotoJpeg);
        expect(base64Decode(sentPhoto['thumbnail']! as String), sampleThumbnailJpeg);
        expect(body['location'], {
          'latitude': -24.045812,
          'longitude': -52.378901,
          'accuracyMeters': 8.5,
        });
        expect(body['description'], draft.description);
      });

      test('deve usar o tempo limite de 60 s no envio e na resposta', () async {
        adapter.reply(201, body: reportJson);

        await sut.create(draft, idempotencyKey: _idempotencyKey);

        final request = adapter.requests.single;
        expect(request.sendTimeout, const Duration(seconds: 60));
        expect(request.receiveTimeout, const Duration(seconds: 60));
      });

      test('deve repetir com a mesma chave depois do timeout (RM24)', () async {
        adapter.failWith(DioExceptionType.receiveTimeout);

        await expectLater(
          sut.create(draft, idempotencyKey: _idempotencyKey),
          throwsA(isA<NetworkException>().having((error) => error.isTimeout, 'isTimeout', isTrue)),
        );

        adapter.reply(201, body: reportJson);
        await sut.create(draft, idempotencyKey: _idempotencyKey);

        expect(
          [for (final request in adapter.requests) request.headers['Idempotency-Key']],
          [_idempotencyKey, _idempotencyKey],
        );
      });

      test('deve converter o 400 da foto, com o campo', () async {
        adapter.reply(
          400,
          body: {
            'statusCode': 400,
            'error': 'Bad Request',
            'message': 'Dados inválidos.',
            'details': [
              {'field': 'photo.content', 'message': 'A foto passa de 2 MB.'},
            ],
          },
        );

        await expectLater(
          sut.create(draft, idempotencyKey: _idempotencyKey),
          throwsA(
            isA<ValidationException>().having(
              (error) => error.messageFor('photo.content'),
              'photo.content',
              'A foto passa de 2 MB.',
            ),
          ),
        );
      });

      test('deve converter o 413 na ServerException com o status', () async {
        adapter.reply(
          413,
          body: {'statusCode': 413, 'error': 'Payload Too Large', 'message': 'Corpo grande.'},
        );

        await expectLater(
          sut.create(draft, idempotencyKey: _idempotencyKey),
          throwsA(isA<ServerException>().having((error) => error.statusCode, 'statusCode', 413)),
        );
      });

      test('deve converter o 422 com a mensagem da API', () async {
        adapter.reply(
          422,
          body: {
            'statusCode': 422,
            'error': 'Unprocessable Entity',
            'message': 'Confirme o seu e-mail para abrir reportes.',
          },
        );

        await expectLater(
          sut.create(draft, idempotencyKey: _idempotencyKey),
          throwsA(
            isA<BusinessRuleException>().having(
              (error) => error.message,
              'message',
              'Confirme o seu e-mail para abrir reportes.',
            ),
          ),
        );
      });

      test('deve converter a resposta fora do formato na ServerException', () async {
        adapter.reply(201, body: {'id': 'sem o resto'});

        await expectLater(
          sut.create(draft, idempotencyKey: _idempotencyKey),
          throwsA(isA<ServerException>()),
        );
      });
    });

    group('listMine', () {
      test('deve chamar o GET /api/reports/mine com a página e o filtro', () async {
        adapter.reply(
          200,
          body: {
            'items': [reportJson],
            'page': 2,
            'pageSize': 20,
            'total': 21,
          },
        );

        final page = await sut.listMine(page: 2, status: ReportStatus.confirmed);

        final request = adapter.requests.single;
        expect(page.items, [sampleReport]);
        expect(page.page, 2);
        expect(request.uri.path, '/api/reports/mine');
        expect(request.uri.queryParameters, {'page': '2', 'pageSize': '20', 'status': 'CONFIRMED'});
      });

      test('deve deixar o filtro de fora com "Todos"', () async {
        adapter.reply(200, body: {'items': <Object?>[], 'page': 1, 'pageSize': 20, 'total': 0});

        await sut.listMine();

        expect(adapter.requests.single.uri.queryParameters, {'page': '1', 'pageSize': '20'});
      });
    });

    group('listNearby', () {
      test('deve chamar o GET /api/reports/nearby com o ponto e o raio', () async {
        adapter.reply(
          200,
          body: {
            'items': [
              {...reportJson, 'distanceMeters': 12},
            ],
          },
        );

        final items = await sut.listNearby(
          const GeoPoint(latitude: -24.045812, longitude: -52.378901),
          radiusMeters: 30,
        );

        final request = adapter.requests.single;
        expect(items.single.distanceMeters, 12);
        expect(request.uri.path, '/api/reports/nearby');
        expect(request.uri.queryParameters, {
          'latitude': '-24.045812',
          'longitude': '-52.378901',
          'radiusMeters': '30',
        });
      });
    });

    group('getById', () {
      test('deve chamar o GET /api/reports/:id', () async {
        adapter.reply(200, body: reportJson);

        expect(await sut.getById(sampleReport.id), sampleReport);
        expect(adapter.requests.single.uri.path, '/api/reports/${sampleReport.id}');
      });

      test('deve converter o 404 do reporte excluído', () async {
        adapter.reply(
          404,
          body: {'statusCode': 404, 'error': 'Not Found', 'message': 'Reporte não encontrado.'},
        );

        await expectLater(
          sut.getById(sampleReport.id),
          throwsA(
            isA<NotFoundException>().having(
              (error) => error.message,
              'message',
              'Reporte não encontrado.',
            ),
          ),
        );
      });
    });

    group('getPhoto', () {
      for (final (size, bytes) in [
        (ReportPhotoSize.full, samplePhotoJpeg),
        (ReportPhotoSize.thumbnail, sampleThumbnailJpeg),
      ]) {
        test('deve buscar e decodificar a imagem no tamanho ${size.apiName}', () async {
          adapter.reply(
            200,
            body: {'id': 'foto-1', 'mimeType': 'image/jpeg', 'content': base64Encode(bytes)},
          );

          final image = await sut.getPhoto(sampleReport.id, size);

          final request = adapter.requests.single;
          expect(image.id, 'foto-1');
          expect(image.bytes, bytes);
          expect(request.uri.path, '/api/reports/${sampleReport.id}/photo');
          expect(request.uri.queryParameters, {'size': size.apiName});
        });
      }

      test('deve converter o conteúdo que não é JPEG na ServerException', () async {
        adapter.reply(
          200,
          body: {'id': 'foto-1', 'mimeType': 'image/png', 'content': base64Encode(samplePng)},
        );

        await expectLater(
          sut.getPhoto(sampleReport.id, ReportPhotoSize.full),
          throwsA(isA<ServerException>()),
        );
      });
    });

    group('update', () {
      test('deve mandar só a descrição no PATCH, com o tempo limite de 60 s', () async {
        adapter.reply(200, body: reportJson);

        final report = await sut.update(sampleReport.id, const ReportChanges(description: ''));

        final request = adapter.requests.single;
        expect(report, sampleReport);
        expect(request.method, 'PATCH');
        expect(request.uri.path, '/api/reports/${sampleReport.id}');
        expect(_sentBody(request), {'description': ''});
        expect(request.sendTimeout, const Duration(seconds: 60));
      });

      test('deve mandar a foto nova em base64', () async {
        adapter.reply(200, body: reportJson);

        await sut.update(sampleReport.id, ReportChanges(photo: photo));

        final body = _sentBody(adapter.requests.single);
        expect(body.keys, ['photo']);
        expect(
          base64Decode((body['photo']! as Map<String, Object?>)['content']! as String),
          samplePhotoJpeg,
        );
      });

      test('deve converter o 422 de quem já votou', () async {
        adapter.reply(
          422,
          body: {
            'statusCode': 422,
            'error': 'Unprocessable Entity',
            'message': 'O reporte já recebeu votos e não pode mais ser editado.',
          },
        );

        await expectLater(
          sut.update(sampleReport.id, const ReportChanges(description: 'Nova')),
          throwsA(isA<BusinessRuleException>()),
        );
      });
    });

    group('delete', () {
      test('deve chamar o DELETE /api/reports/:id', () async {
        adapter.reply(204);

        await sut.delete(sampleReport.id);

        final request = adapter.requests.single;
        expect(request.method, 'DELETE');
        expect(request.uri.path, '/api/reports/${sampleReport.id}');
      });

      test('deve converter a falta de conexão', () async {
        adapter.failWith(DioExceptionType.connectionError);

        await expectLater(sut.delete(sampleReport.id), throwsA(isA<NetworkException>()));
      });
    });

    group('vote', () {
      const location = GeoLocation(latitude: -24.0459, longitude: -52.3788, accuracyMeters: 12);

      Map<String, Object?> error(int status, String message) => {
        'statusCode': status,
        'error': 'Erro',
        'message': message,
      };

      test('deve mandar o voto e a localização no POST /api/reports/:id/votes e devolver o '
          'reporte atualizado (RM29 e RM30)', () async {
        adapter.reply(
          201,
          body: {
            ...reportJson,
            'isMine': false,
            'canDelete': false,
            'votes': {
              ...(reportJson['votes']! as Map<String, Object?>),
              'confirmations': 4,
              'mine': 'CONFIRM',
            },
          },
        );

        final report = await sut.vote(sampleReport.id, VoteType.confirm, location);

        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/reports/${sampleReport.id}/votes');
        expect(_sentBody(request), {
          'vote': 'CONFIRM',
          'location': {'latitude': -24.0459, 'longitude': -52.3788, 'accuracyMeters': 12},
        });
        expect(report.votes.confirmations, 4);
        expect(report.votes.mine, VoteType.confirm);
        expect(report.canVote, isFalse);
      });

      test('deve converter o 409 do voto repetido', () async {
        adapter.reply(409, body: error(409, 'Você já votou neste reporte.'));

        await expectLater(
          sut.vote(sampleReport.id, VoteType.deny, location),
          throwsA(
            isA<ConflictException>().having(
              (error) => error.message,
              'message',
              'Você já votou neste reporte.',
            ),
          ),
        );
      });

      test('deve converter o 422 de quem está longe, com a mensagem da API', () async {
        adapter.reply(
          422,
          body: error(422, 'Você precisa estar a até 500 m do reporte para votar.'),
        );

        await expectLater(
          sut.vote(sampleReport.id, VoteType.confirm, location),
          throwsA(
            isA<BusinessRuleException>().having(
              (error) => error.message,
              'message',
              'Você precisa estar a até 500 m do reporte para votar.',
            ),
          ),
        );
      });

      test('deve converter o 404 do reporte excluído no meio do voto', () async {
        adapter.reply(404, body: error(404, 'Reporte não encontrado.'));

        await expectLater(
          sut.vote(sampleReport.id, VoteType.confirm, location),
          throwsA(isA<NotFoundException>()),
        );
      });
    });
  });
}
