import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/utils/uuid.dart';

/// O formato do UUID v4: a versão 4 e a variante `8`, `9`, `a` ou `b`.
final _uuidV4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

void main() {
  group('randomUuidV4', () {
    test('deve gerar um UUID versão 4, em minúsculas', () {
      for (var i = 0; i < 100; i++) {
        expect(randomUuidV4(), matches(_uuidV4));
      }
    });

    test('não deve repetir', () {
      final keys = {for (var i = 0; i < 1000; i++) randomUuidV4()};

      expect(keys, hasLength(1000));
    });

    test('deve usar o gerador passado', () {
      expect(randomUuidV4(Random(1)), randomUuidV4(Random(1)));
      expect(randomUuidV4(Random(1)), isNot(randomUuidV4(Random(2))));
    });
  });
}
