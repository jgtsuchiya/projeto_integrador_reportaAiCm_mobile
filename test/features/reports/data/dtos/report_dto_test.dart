import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/reports/data/dtos/report_dto.dart';
import 'package:reportaai_cm/features/reports/data/dtos/report_list_dtos.dart';
import 'package:reportaai_cm/features/reports/data/dtos/report_photo_dto.dart';
import 'package:reportaai_cm/features/reports/data/dtos/report_request_dtos.dart';
import 'package:reportaai_cm/features/reports/domain/models/geo_location.dart';
import 'package:reportaai_cm/features/reports/domain/models/prepared_photo.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_draft.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';
import 'package:reportaai_cm/features/reports/domain/models/vote_type.dart';

import '../../../../support/fake_report_repository.dart';
import '../../../../support/sample_images.dart';

Map<String, Object?> _json(Map<String, Object?> changes) => {...reportJson, ...changes};

Map<String, Object?> _without(String key) => {...reportJson}..remove(key);

void main() {
  group('ReportDto', () {
    test('deve ler o reporte do exemplo do plano do backend', () {
      expect(ReportDto.fromJson(reportJson).toModel(), sampleReport);
    });

    test('deve ler o reporte sem a descrição e sem a chave dela', () {
      expect(ReportDto.fromJson(_json({'description': null})).toModel().description, isNull);
      expect(ReportDto.fromJson(_without('description')).toModel().description, isNull);
    });

    test('deve ler o distanceMeters do reporte perto', () {
      final report = ReportDto.fromJson(_json({'distanceMeters': 120})).toModel();

      expect(report.distanceMeters, 120);
      expect(ReportDto.fromJson(reportJson).toModel().distanceMeters, isNull);
    });

    test('deve ler o voto do cidadão e o canVote da validação', () {
      Map<String, Object?> votes(Object? mine) => {
        ...(reportJson['votes']! as Map<String, Object?>),
        'mine': mine,
      };

      final open = ReportDto.fromJson(_json({'isMine': false, 'canVote': true})).toModel();
      final confirmed = ReportDto.fromJson(_json({'votes': votes('CONFIRM')})).toModel();
      final denied = ReportDto.fromJson(_json({'votes': votes('DENY')})).toModel();

      expect(open.canVote, isTrue);
      expect(open.votes.mine, isNull);
      expect(confirmed.votes.mine, VoteType.confirm);
      expect(denied.votes.mine, VoteType.deny);
      expect(confirmed.canVote, isFalse);
    });

    test('deve ler o reporte sem o voto de uma API só com a abertura dos reportes', () {
      final votes = {...(reportJson['votes']! as Map<String, Object?>)}..remove('mine');

      final report = ReportDto.fromJson({..._without('canVote'), 'votes': votes}).toModel();

      expect(report.canVote, isFalse);
      expect(report.votes.mine, isNull);
    });

    test('deve ler o voto que o app não conhece como sem voto', () {
      final report = ReportDto.fromJson(
        _json({
          'votes': {...(reportJson['votes']! as Map<String, Object?>), 'mine': 'UNSURE'},
        }),
      ).toModel();

      expect(report.votes.mine, isNull);
    });

    test('deve ler o status desconhecido como o unknown, sem erro', () {
      final report = ReportDto.fromJson(_json({'status': 'IN_PROGRESS'})).toModel();

      expect(report.status, ReportStatus.unknown);
    });

    test('deve ler o reporte confirmado, com a data da mudança', () {
      final report = ReportDto.fromJson(
        _json({'status': 'CONFIRMED', 'statusChangedAt': '2026-11-10T08:00:00.000Z'}),
      ).toModel();

      expect(report.status, ReportStatus.confirmed);
      expect(report.statusChangedAt, DateTime.utc(2026, 11, 10, 8));
    });

    test('deve aceitar a precisão com casas e os inteiros escritos com o ponto', () {
      final report = ReportDto.fromJson(
        _json({
          'location': {'latitude': -24, 'longitude': -52.5, 'accuracyMeters': 8.5},
          'distanceMeters': 30.0,
        }),
      ).toModel();

      expect(
        report.location,
        const GeoLocation(latitude: -24, longitude: -52.5, accuracyMeters: 8.5),
      );
      expect(report.distanceMeters, 30);
    });

    for (final (description, json, field) in [
      ('a resposta que não é um objeto', <String, Object?>{}, 'reporte'),
      ('sem o id', _without('id'), 'id'),
      ('o status que não é texto', _json({'status': 1}), 'status'),
      ('sem a localização', _without('location'), 'location'),
      (
        'a latitude que não é número',
        _json({
          'location': {'latitude': '-24', 'longitude': -52, 'accuracyMeters': 9},
        }),
        'location.latitude',
      ),
      (
        'a contagem com casas',
        _json({
          'votes': {
            'confirmations': 1.5,
            'rejections': 0,
            'confirmationsRequired': 10,
            'rejectionsRequired': 10,
          },
        }),
        'votes.confirmations',
      ),
      ('a data fora do formato', _json({'createdAt': 'ontem'}), 'createdAt'),
      ('sem a data de criação', _without('createdAt'), 'createdAt'),
      ('sem o canEdit', _without('canEdit'), 'canEdit'),
      ('o canVote que não é booleano', _json({'canVote': 'sim'}), 'canVote'),
      (
        'o voto que não é texto',
        _json({
          'votes': {...(reportJson['votes']! as Map<String, Object?>), 'mine': 1},
        }),
        'votes.mine',
      ),
    ]) {
      test('deve lançar a FormatException com $description, só com o nome do campo', () {
        final input = description == 'a resposta que não é um objeto' ? 'texto' : json;

        expect(
          () => ReportDto.fromJson(input),
          throwsA(
            isA<FormatException>()
                .having((error) => error.message, 'message', contains('"$field"'))
                .having((error) => error.message, 'message', isNot(contains('-24'))),
          ),
        );
      });
    }
  });

  group('ReportPageDto e NearbyReportsDto', () {
    test('deve ler a página de "Meus reportes"', () {
      final page = ReportPageDto.fromJson({
        'items': [reportJson],
        'page': 2,
        'pageSize': 20,
        'total': 21,
      }).toModel();

      expect(page.items, [sampleReport]);
      expect((page.page, page.pageSize, page.total, page.hasMore), (2, 20, 21, false));
    });

    test('deve ler a lista dos reportes perto, com a distância', () {
      final items = NearbyReportsDto.fromJson({
        'items': [
          _json({'distanceMeters': 12, 'isMine': false, 'canDelete': false}),
        ],
      }).toModel();

      expect(items.single.distanceMeters, 12);
      expect(items.single.isMine, isFalse);
    });

    test('deve recusar a página e a lista fora do formato', () {
      expect(() => ReportPageDto.fromJson({'items': <Object?>[]}), throwsFormatException);
      expect(() => ReportPageDto.fromJson([reportJson]), throwsFormatException);
      expect(() => NearbyReportsDto.fromJson([reportJson]), throwsFormatException);
      expect(
        () => NearbyReportsDto.fromJson({
          'items': [_without('id')],
        }),
        throwsFormatException,
      );
    });
  });

  group('ReportPhotoDto', () {
    test('deve decodificar o base64 da imagem', () {
      final image = ReportPhotoDto.fromJson({
        'id': 'foto-1',
        'mimeType': 'image/jpeg',
        'content': base64Encode(samplePhotoJpeg),
      }).toModel();

      expect(image.id, 'foto-1');
      expect(image.bytes, samplePhotoJpeg);
    });

    test('deve recusar a resposta sem o conteúdo e o conteúdo que não é JPEG', () {
      expect(() => ReportPhotoDto.fromJson({'id': 'foto-1'}), throwsFormatException);
      expect(
        () =>
            ReportPhotoDto.fromJson({'id': 'foto-1', 'content': base64Encode(samplePng)}).toModel(),
        throwsFormatException,
      );
    });
  });

  group('Corpos da abertura e da edição', () {
    final photo = PreparedPhoto.create(photo: samplePhotoJpeg, thumbnail: sampleThumbnailJpeg);
    const location = GeoLocation(latitude: -24.045812, longitude: -52.378901, accuracyMeters: 8.5);

    test('deve montar o corpo da abertura com a foto em base64', () {
      final json = OpenReportRequestDto(
        ReportDraft(location: location, photo: photo, description: 'Perto do semáforo'),
      ).toJson();

      expect(json, {
        'description': 'Perto do semáforo',
        'location': {'latitude': -24.045812, 'longitude': -52.378901, 'accuracyMeters': 8.5},
        'photo': {
          'content': base64Encode(samplePhotoJpeg),
          'thumbnail': base64Encode(sampleThumbnailJpeg),
        },
      });
    });

    test('deve deixar a descrição de fora do corpo da abertura quando não há', () {
      final json = OpenReportRequestDto(ReportDraft(location: location, photo: photo)).toJson();

      expect(json.containsKey('description'), isFalse);
    });

    test('deve mandar só o que muda na edição, e nunca a localização', () {
      expect(const EditReportRequestDto(ReportChanges(description: 'Nova')).toJson(), {
        'description': 'Nova',
      });
      expect(const EditReportRequestDto(ReportChanges(description: '')).toJson(), {
        'description': '',
      });
      expect(EditReportRequestDto(ReportChanges(photo: photo)).toJson(), {
        'photo': {
          'content': base64Encode(samplePhotoJpeg),
          'thumbnail': base64Encode(sampleThumbnailJpeg),
        },
      });
    });

    test('deve montar o corpo do voto com o código da API e a localização (RN38)', () {
      expect(const VoteRequestDto(VoteType.confirm, location).toJson(), {
        'vote': 'CONFIRM',
        'location': {'latitude': -24.045812, 'longitude': -52.378901, 'accuracyMeters': 8.5},
      });
      expect(const VoteRequestDto(VoteType.deny, location).toJson()['vote'], 'DENY');
    });
  });
}
