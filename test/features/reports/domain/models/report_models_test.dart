import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/reports/domain/models/geo_location.dart';
import 'package:reportaai_cm/features/reports/domain/models/prepared_photo.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_description.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_draft.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_page.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_status.dart';

import '../../../../support/fake_report_repository.dart';
import '../../../../support/sample_images.dart';

void main() {
  group('ReportStatus', () {
    test('deve ler os códigos da API', () {
      expect(ReportStatus.fromApiName('PENDING'), ReportStatus.pending);
      expect(ReportStatus.fromApiName('CONFIRMED'), ReportStatus.confirmed);
      expect(ReportStatus.fromApiName('REJECTED'), ReportStatus.rejected);
    });

    test('deve tratar o status que o painel vai criar como desconhecido, sem erro', () {
      expect(ReportStatus.fromApiName('IN_PROGRESS'), ReportStatus.unknown);
      expect(ReportStatus.unknown.apiName, isNull);
    });
  });

  group('ReportVotes', () {
    ReportVotes votes(int confirmations, {int required = 10}) => ReportVotes(
      confirmations: confirmations,
      rejections: 0,
      confirmationsRequired: required,
      rejectionsRequired: 10,
    );

    test('deve calcular o progresso das confirmações, de 0 a 1', () {
      expect(votes(0).confirmationProgress, 0);
      expect(votes(3).confirmationProgress, 0.3);
      expect(votes(10).confirmationProgress, 1);
      expect(votes(12).confirmationProgress, 1);
      expect(votes(1, required: 0).confirmationProgress, 0);
    });

    test('deve comparar pelas contagens e descrevê-las', () {
      expect(votes(3), votes(3));
      expect(votes(3).hashCode, votes(3).hashCode);
      expect(votes(3), isNot(votes(4)));
      expect(votes(3).toString(), 'ReportVotes(3 de 10 confirmações, 0 de 10 negativas)');
    });
  });

  group('GeoPoint e GeoLocation', () {
    const location = GeoLocation(latitude: -24.0458, longitude: -52.3789, accuracyMeters: 8.5);

    test('deve comparar pelas coordenadas e devolver o ponto', () {
      expect(
        location,
        const GeoLocation(latitude: -24.0458, longitude: -52.3789, accuracyMeters: 8.5),
      );
      expect(location.hashCode, location.hashCode);
      expect(location.point, const GeoPoint(latitude: -24.0458, longitude: -52.3789));
      expect(location.point.hashCode, location.point.hashCode);
    });

    test('não deve mostrar as coordenadas no texto (RM27)', () {
      for (final text in [location.toString(), location.point.toString()]) {
        expect(text, isNot(contains('24.0458')));
        expect(text, isNot(contains('52.3789')));
      }
      expect(location.toString(), contains('accuracyMeters: 8.5'));
    });
  });

  group('Report', () {
    test('deve comparar pelos campos', () {
      expect(sampleReportWith(), sampleReport);
      expect(sampleReportWith().hashCode, sampleReport.hashCode);
      expect(sampleReportWith(confirmations: 4), isNot(sampleReport));
      expect(sampleReport.photo.hashCode, sampleReportWith().photo.hashCode);
      expect(sampleReport.photo.toString(), contains('1600x1200'));
    });

    test('não deve mostrar a descrição nem as coordenadas no texto (RM27)', () {
      final text = sampleReport.toString();

      expect(text, contains(sampleReport.id));
      expect(text, isNot(contains('semáforo')));
      expect(text, isNot(contains('24.04')));
    });
  });

  group('ReportPage', () {
    test('deve dizer se há outra página', () {
      ReportPage page(int number, int total) =>
          ReportPage(items: const [], page: number, pageSize: 20, total: total);

      expect(page(1, 21).hasMore, isTrue);
      expect(page(1, 20).hasMore, isFalse);
      expect(page(2, 41).hasMore, isTrue);
      expect(page(1, 0).hasMore, isFalse);
    });

    test('deve comparar pelos itens e pelos números', () {
      final page = ReportPage(items: [sampleReport], page: 1, pageSize: 20, total: 1);

      expect(page, ReportPage(items: [sampleReport], page: 1, pageSize: 20, total: 1));
      expect(
        page.hashCode,
        ReportPage(items: [sampleReport], page: 1, pageSize: 20, total: 1).hashCode,
      );
      expect(page, isNot(const ReportPage(items: [], page: 1, pageSize: 20, total: 1)));
      expect(
        page,
        isNot(ReportPage(items: [sampleReportWith(id: 'x')], page: 1, pageSize: 20, total: 1)),
      );
      expect(page.toString(), 'ReportPage(1 reportes, page: 1, pageSize: 20, total: 1)');
    });
  });

  group('Descrição do reporte', () {
    test('deve tirar os espaços das pontas e tratar a vazia como sem descrição', () {
      expect(normalizeReportDescription('  Buraco fundo  '), 'Buraco fundo');
      expect(normalizeReportDescription('   '), isNull);
    });

    test('deve aceitar até 500 caracteres, contando o emoji como um, como a API (RN27)', () {
      expect(isValidReportDescription('a' * 500), isTrue);
      expect(isValidReportDescription('  ${'a' * 500}  '), isTrue);
      expect(isValidReportDescription('a' * 501), isFalse);
      expect(isValidReportDescription('🕳' * 500), isTrue);
      expect(isValidReportDescription('🕳' * 501), isFalse);
      expect(descriptionTooLongMessage, 'A descrição deve ter no máximo 500 caracteres.');
    });
  });

  group('ReportDraft e ReportChanges', () {
    final photo = PreparedPhoto.create(photo: samplePhotoJpeg, thumbnail: sampleThumbnailJpeg);
    const location = GeoLocation(latitude: -24, longitude: -52, accuracyMeters: 8);

    test('deve comparar o rascunho e não mostrar a descrição no texto', () {
      final draft = ReportDraft(location: location, photo: photo, description: 'Na esquina');

      expect(draft, ReportDraft(location: location, photo: photo, description: 'Na esquina'));
      expect(
        draft.hashCode,
        ReportDraft(location: location, photo: photo, description: 'Na esquina').hashCode,
      );
      expect(draft.toString(), isNot(contains('Na esquina')));
      expect(draft.toString(), contains('com descrição: true'));
    });

    test('deve diferenciar o "não mudar" do "apagar" a descrição', () {
      expect(const ReportChanges().isEmpty, isTrue);
      expect(const ReportChanges().removesDescription, isFalse);
      expect(const ReportChanges(description: '').isEmpty, isFalse);
      expect(const ReportChanges(description: '').removesDescription, isTrue);
      expect(const ReportChanges(description: 'Nova').removesDescription, isFalse);
      expect(ReportChanges(photo: photo).isEmpty, isFalse);
    });

    test('deve comparar as mudanças', () {
      expect(const ReportChanges(description: 'a'), const ReportChanges(description: 'a'));
      expect(
        const ReportChanges(description: 'a').hashCode,
        const ReportChanges(description: 'a').hashCode,
      );
      expect(const ReportChanges(description: 'a').toString(), contains('description: a'));
    });

    test('deve descrever a imagem sem os bytes', () {
      final image = ReportPhotoImage(id: 'foto', bytes: samplePhotoJpeg);

      expect(image, image);
      expect(image.hashCode, image.hashCode);
      expect(image.toString(), 'ReportPhotoImage(foto, ${samplePhotoJpeg.length} bytes)');
      expect(ReportPhotoSize.thumbnail.apiName, 'thumbnail');
    });
  });
}
