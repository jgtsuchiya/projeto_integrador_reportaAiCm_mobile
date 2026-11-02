import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/health/data/dtos/health_status_dto.dart';
import 'package:reportaai_cm/features/health/domain/models/health_status.dart';

void main() {
  group('HealthStatusDto', () {
    test('deve ler o JSON da API e converter no modelo', () {
      final sut = HealthStatusDto.fromJson({
        'status': 'ok',
        'timestamp': '2026-10-20T15:30:00.000Z',
      });

      expect(
        sut.toModel(),
        HealthStatus(status: 'ok', checkedAt: DateTime.utc(2026, 10, 20, 15, 30)),
      );
    });

    test('deve recusar o JSON fora do formato', () {
      for (final json in <Object?>[
        null,
        'ok',
        <String, Object?>{},
        {'status': 'ok'},
        {'status': 1, 'timestamp': '2026-10-20T15:30:00.000Z'},
        {'status': 'ok', 'timestamp': 'ontem'},
      ]) {
        expect(() => HealthStatusDto.fromJson(json), throwsFormatException, reason: '$json');
      }
    });
  });
}
