import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/core/utils/cpf_formatters.dart';

void main() {
  group('maskCpf', () {
    test('deve mostrar só os seis dígitos do meio, como no painel (RN12)', () {
      expect(maskCpf('52998224725'), '***.982.247-**');
    });

    test('deve mascarar o mesmo trecho do backend', () {
      // O exemplo do Cpf.masked() do backend.
      expect(maskCpf('12345678909'), '***.456.789-**');
    });

    for (final cpf in ['529.982.247-25', '5299822472', '529982247250', '', 'abcdefghijk']) {
      test('deve mascarar todos os dígitos fora do formato da API: "$cpf" (RM09)', () {
        expect(maskCpf(cpf), '***.***.***-**');
      });
    }
  });

  group('CpfInputFormatter', () {
    const sut = CpfInputFormatter();

    test('deve formatar no 000.000.000-00, com até 11 dígitos', () {
      expect(sut.maxDigits, 11);
      expect(sut.format('52998224725'), '529.982.247-25');
      expect(sut.format('5299'), '529.9');
    });
  });
}
