import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/health/domain/models/health_status.dart';

void main() {
  group('HealthStatus', () {
    final checkedAt = DateTime.utc(2026, 10, 20, 15, 30);

    test('deve estar ok só com o status "ok"', () {
      expect(HealthStatus(status: 'ok', checkedAt: checkedAt).isOk, isTrue);
      expect(HealthStatus(status: 'degraded', checkedAt: checkedAt).isOk, isFalse);
    });

    test('deve comparar pelo valor', () {
      expect(
        HealthStatus(status: 'ok', checkedAt: checkedAt),
        HealthStatus(status: 'ok', checkedAt: DateTime.utc(2026, 10, 20, 15, 30)),
      );
      expect(
        HealthStatus(status: 'ok', checkedAt: checkedAt),
        isNot(HealthStatus(status: 'ok', checkedAt: checkedAt.add(const Duration(seconds: 1)))),
      );
    });
  });
}
